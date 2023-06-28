defmodule State.ConnectingStops do
  @moduledoc """
  Determines which stops should be considered "connections" from a given stop.

  Connections are generated as follows: For each parent station, find all "standalone" stops
  (location type 0 with no parent station) within a small radius of either all station entrances,
  or the station itself if it has no entrances. "Connect" the station and each of these stops to
  each other. Then, considering the combined list of connections "from" each station/stop, remove
  any that only serve route patterns also served by a closer connection (or the stop itself).
  """
  use Events.Server
  alias Model.{RoutePattern, Stop}
  alias State.RoutesPatternsAtStop
  require Logger

  @type overrides :: %{Stop.id() => %{add: [Stop.id()], remove: [Stop.id()]}}
  @type state :: nil

  # 99 to 133 meters, depending on how much of the distance is across longitude resp. latitude
  @radius 0.0012
  @sources [RoutesPatternsAtStop, State.Stop]
  @table __MODULE__

  # Overrides whether a stop is considered "close" to a parent station during the initial search.
  # This allows modifying groups of connected stops without manually specifying every connection,
  # but note this happens _before_ pruning redundant connections: added stops can be filtered out,
  # and removing a stop can "create" a new connection further away.
  @overrides %{
    "place-brmnl" => %{add: ~w(21317 92391)},
    "place-hsmnl" => %{add: ~w(22365 65741)},
    "place-DB-2205" => %{add: ~w(16391)},
    "place-FR-0064" => %{add: ~w(2137)},
    "place-GRB-0118" => %{add: ~w(3806)},
    "place-harsq" => %{add: ~w(110)},
    "place-aqucl" => %{add: ~w(Boat-Long Boat-Long-South-4 Boat-Aquarium)},
    "Boat-Charlestown" => %{add: ~w(12859 12856)}
  }

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Find stops that are connections from the given stop ID."
  @spec for_stop_id(Stop.id()) :: [Stop.t()]
  def for_stop_id(stop_id) do
    case :ets.lookup(@table, stop_id) do
      [] -> []
      [{_, stop_ids}] -> State.Stop.by_ids(stop_ids)
    end
  end

  @doc "Dump a list of all parent stations with their connected stops, for debugging."
  def inspect do
    [1]
    |> State.Stop.by_location_type()
    |> Enum.map(&[&1 | for_stop_id(&1.id)])
    |> Enum.reject(fn stops -> length(stops) < 2 end)
    |> Enum.map(fn stops ->
      Enum.map(stops, &{&1.id, &1.name, &1 |> patterns_at_stop() |> Enum.sort()})
    end)
  end

  @doc "Force a synchronous state update, for use in tests."
  def update!(overrides \\ @overrides) do
    :ok = GenServer.call(__MODULE__, {:update!, overrides})
  end

  @impl Events.Server
  def handle_event(_, _, _, state) do
    {:noreply, maybe_update(state), :hibernate}
  end

  @impl GenServer
  def init(_) do
    @table = :ets.new(@table, [:named_table, read_concurrency: true])
    Events.publish({:new_state, __MODULE__}, 0)
    for server <- @sources, do: Events.subscribe({:new_state, server})
    {:ok, maybe_update(nil), :hibernate}
  end

  @impl GenServer
  def handle_call({:update!, overrides}, _from, state) do
    {:reply, :ok, update_state(state, overrides), :hibernate}
  end

  @spec maybe_update(state) :: state
  defp maybe_update(state) do
    # Normally sources should only be empty if they are still initializing their own state, so in
    # that case we shouldn't update ours yet
    if Enum.all?(@sources, &(&1.size > 0)), do: update_state(state), else: state
  end

  @spec update_state(state, overrides) :: state
  defp update_state(state, overrides \\ @overrides) do
    stops = State.Stop.by_location_type([1]) ++ State.Stop.by_vehicle_types([4])

    items =
      stops
      |> Stream.filter(&Stop.located?/1)
      |> Stream.map(fn stop -> [stop | connecting_stops(stop, overrides)] end)
      |> Stream.flat_map(&rotations/1)
      |> group_and_merge_by_head()
      |> Stream.map(fn {stop, stops} -> {stop, reject_redundant_connections(stop, stops)} end)
      |> Enum.map(fn {stop, stops} -> {stop.id, Enum.map(stops, & &1.id)} end)

    :ets.delete_all_objects(@table)
    :ets.insert(@table, items)
    size = length(items)

    _ =
      Logger.info(fn ->
        "Update #{__MODULE__} #{inspect(self())}: #{size} items"
      end)

    publish({:new_state, __MODULE__}, size)
    state
  end

  # Find possible connecting stops for a given stop, taking overrides into account.
  @spec connecting_stops(Stop.t(), overrides) :: [Stop.t()]
  defp connecting_stops(stop, overrides) do
    stop
    |> standalone_stops_near()
    |> MapSet.new()
    |> MapSet.union(MapSet.new(override_stops(overrides, stop, :add)))
    |> MapSet.difference(MapSet.new(override_stops(overrides, stop, :remove)))
    |> MapSet.to_list()
  end

  # Find "standalone" stops close to a given stop's entrances, if it has entrances, otherwise
  # close to the stop itself.
  @spec standalone_stops_near(Stop.t()) :: [Stop.t()]
  defp standalone_stops_near(%{id: stop_id, latitude: latitude, longitude: longitude}) do
    case State.Stop.by_parent_station_and_location_type(stop_id, 2) do
      [] ->
        # credo:disable-for-next-line Credo.Check.Refactor.PipeChainStart
        State.Stop.around(latitude, longitude, @radius) |> Enum.filter(&Stop.standalone?/1)

      entrances ->
        entrances |> Stream.flat_map(&standalone_stops_near/1) |> Enum.uniq()
    end
  end

  # Get stops that should be added/removed from a given parent station's connections.
  @spec override_stops(overrides, Stop.t(), :add | :remove) :: [Stop.t()]
  defp override_stops(overrides, %{id: stop_id}, kind) when kind in [:add, :remove] do
    overrides |> Map.get(stop_id, %{}) |> Map.get(kind, []) |> State.Stop.by_ids()
  end

  # Return all rotations of a non-empty list.
  # Example: [1, 2, 3] => [[1, 2, 3], [2, 3, 1], [3, 1, 2]]
  @spec rotations([...]) :: [[...]]
  defp rotations([item]), do: [[item]]

  defp rotations([_ | _] = items) do
    0..(length(items) - 1)
    |> Enum.map(fn count ->
      {before, [first | rest]} = Enum.split(items, count)
      [first | before ++ rest]
    end)
  end

  # Given an enumerable of lists, split them into heads and tails, group tails that share a head,
  # then flatten and uniq the tails for each head.
  # Example: [[1, 2, 3], [1, 3, 4], [2, 3, 4]] => [{1, [2, 3, 4]}, {2, [3, 4]}]
  @spec group_and_merge_by_head(Enumerable.t()) :: Enumerable.t()
  defp group_and_merge_by_head(lists) do
    lists
    |> Enum.group_by(&hd/1, &tl/1)
    |> Stream.map(fn {head, tails} -> {head, tails |> List.flatten() |> Enum.uniq()} end)
  end

  # Given a stop and a list of possible connecting stops, sorts the connections by distance from
  # the "base" stop, then rejects any that only serve route patterns also served by the base stop
  # or a closer connection.
  @spec reject_redundant_connections(Stop.t(), [Stop.t()]) :: [Stop.t()]
  defp reject_redundant_connections(from_stop, connecting_stops) do
    connecting_stops
    |> Enum.sort_by(GeoDistance.cmp(from_stop.latitude, from_stop.longitude))
    |> Stream.map(fn stop -> {stop, patterns_at_stop(stop)} end)
    |> Enum.reduce({[], patterns_at_stop(from_stop)}, fn
      {stop, stop_patterns}, {stops, seen_patterns} ->
        if MapSet.subset?(stop_patterns, seen_patterns),
          do: {stops, seen_patterns},
          else: {[stop | stops], MapSet.union(seen_patterns, stop_patterns)}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  @spec patterns_at_stop(Stop.t()) :: MapSet.t(RoutePattern.id())
  defp patterns_at_stop(%{id: id}) do
    [id] |> RoutesPatternsAtStop.route_patterns_by_family_stops(canonical?: false) |> MapSet.new()
  end
end
