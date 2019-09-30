defmodule State.StopsOnRoute do
  @moduledoc """

  Maintains an ETS-based cache of the stops (in order) for a route.

  """
  use Events.Server
  require Logger
  alias State.Schedule
  import State.Helpers
  import State.Logger

  @table __MODULE__

  @type stop_id_list :: [Model.Stop.id()]

  @typep record ::
           {Model.Route.id(), Model.Direction.id(), Model.Shape.id(), Model.Service.id(),
            stop_id_list}

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def size do
    safe_ets_size(@table)
  end

  @spec by_route_id(Model.Route.id(), Keyword.t()) :: stop_id_list
  def by_route_id(route_id, opts \\ []) do
    by_route_ids([route_id], opts)
  end

  @spec by_route_ids([Model.Route.id()], Keyword.t()) :: stop_id_list
  def by_route_ids(route_ids, opts \\ []) do
    direction_id = Keyword.get(opts, :direction_id, :_)
    alternate? = if opts[:include_alternates?], do: :_, else: false

    matchers =
      for service_id <- Keyword.get(opts, :service_ids, [:_]),
          shape_id <- Keyword.get(opts, :shape_ids, [:all]),
          route_id <- route_ids do
        {{route_id, direction_id, shape_id, service_id, alternate?, :"$1"}, [], [:"$1"]}
      end

    results = :ets.select(@table, matchers)

    if results == [] and !opts[:include_alternates?] do
      # we didn't get any results, try including the alternate routes
      by_route_ids(route_ids, put_in(opts[:include_alternates?], true))
    else
      merge_ids(results)
    end
  end

  def update! do
    GenServer.call(__MODULE__, :update!)
  end

  def empty! do
    GenServer.call(__MODULE__, :empty!)
  end

  @impl Events.Server
  def handle_event(_, _, _, state) do
    {_, _, state, _} = handle_call(:update!, nil, state)
    {:noreply, state, :hibernate}
  end

  @impl GenServer
  def init(_) do
    subscriptions = [
      {:new_state, State.Route},
      {:new_state, State.Trip},
      {:new_state, State.Shape},
      {:new_state, State.Schedule}
    ]

    for subscription <- subscriptions do
      subscribe(subscription)
    end

    @table = :ets.new(@table, [:named_table, :duplicate_bag, {:read_concurrency, true}])
    {:ok, nil}
  end

  @impl GenServer
  def handle_call(:update!, _from, state) do
    _ =
      debug_time(
        fn ->
          State.Route.all()
          |> Stream.map(&do_gather_route/1)
          |> Enum.reduce(:full, &do_reduce/2)
        end,
        # no cover
        fn milliseconds -> "handle_call #{__MODULE__} took #{milliseconds}ms" end
      )

    number_of_items = size()
    _ = Logger.info(fn -> "Update #{__MODULE__}: #{number_of_items} items" end)
    publish({:new_state, __MODULE__}, number_of_items)

    {:reply, :ok, state, :hibernate}
  end

  @impl GenServer
  def handle_call(:empty!, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, state, :hibernate}
  end

  @spec do_gather_route(Model.Route.t()) :: [record]
  defp do_gather_route(route) do
    route.id
    |> State.Trip.by_route_id()
    |> Enum.group_by(& &1.direction_id)
    |> Enum.flat_map(fn {direction_id, trips} ->
      do_gather_route_direction(route, direction_id, trips)
    end)
  end

  @spec do_gather_route_direction(Model.Route.t(), Model.Direction.id(), [Model.Trip.t()]) ::
          [record]
  defp do_gather_route_direction(route, direction_id, trips) do
    global_stop_id_order = order_stop_ids_for_trips(route, direction_id, trips)

    # stops broken down by shape
    shape_records =
      trips
      |> Enum.group_by(fn trip ->
        ignore? = ignore_trip_for_route?(trip)
        {ignore?, trip.shape_id, trip.service_id, trip.direction_id}
      end)
      |> Enum.flat_map(&do_gather_direction_group(route, global_stop_id_order, &1))

    # stops not broken down by shape or pattern
    other_records =
      trips
      |> Enum.group_by(fn trip ->
        {ignore_trip_route_pattern?(trip), :all, trip.service_id, trip.direction_id}
      end)
      |> Enum.flat_map(&do_gather_direction_group(route, global_stop_id_order, &1))

    Enum.concat(shape_records, other_records)
  end

  defp do_gather_direction_group(route, global_order, {group_key, trip_group}) do
    {ignore?, shape_id, service_id, direction_id} = group_key

    stop_ids =
      trip_group
      |> stop_ids_for_trips()
      |> merge_group_stop_ids(global_order)

    if stop_ids == [] do
      []
    else
      [
        {route.id, direction_id, shape_id, service_id, ignore?, stop_ids}
      ]
    end
  end

  def stop_ids_for_trips(trips) do
    trips
    |> Stream.map(fn trip ->
      trip.id
      |> Schedule.by_trip_id()
      |> Enum.sort_by(& &1.stop_sequence)
      |> Enum.map(& &1.stop_id)
      |> map_parent_stations
    end)
    |> Enum.uniq()
  end

  @spec order_stop_ids_for_trips(Model.Route.t(), Model.Direction.id(), [Model.Trip.t()]) ::
          stop_id_list
  defp order_stop_ids_for_trips(route, direction_id, trips) do
    trip_stops =
      trips
      |> Stream.reject(&ignore_trip_for_route?/1)
      |> stop_ids_for_trips()

    overrides = stop_order_overrides(route.id, direction_id, trip_stops)

    merge_ids(trip_stops, overrides)
  end

  @spec merge_group_stop_ids([stop_id_list], stop_id_list) :: stop_id_list
  defp merge_group_stop_ids([], _global_order) do
    []
  end

  defp merge_group_stop_ids([single_group], _global_order) do
    # if there's a single group of stops, let it keep the ordering
    single_group
  end

  defp merge_group_stop_ids(groups, global_order) do
    group_stop_id_map =
      groups
      |> Enum.map(&MapSet.new/1)
      |> Enum.reduce(&MapSet.union/2)

    Enum.filter(global_order, &MapSet.member?(group_stop_id_map, &1))
  end

  # additional ordered stop IDs to include during the merge
  @spec stop_order_overrides(Model.Route.id(), Model.Direction.id(), [stop_id_list]) :: [
          stop_id_list
        ]
  defp stop_order_overrides(route_id, direction_id, stop_lists) do
    config = Application.get_env(:state, :stops_on_route)[:stop_order_overrides]

    case Map.fetch(config, {route_id, direction_id}) do
      {:ok, overrides} ->
        stop_set = Enum.reduce(stop_lists, MapSet.new(), &MapSet.union(&2, MapSet.new(&1)))
        # filter out overrides which don't intersect these stops
        for override <- overrides,
            not MapSet.disjoint?(stop_set, MapSet.new(override)) do
          override
        end

      :error ->
        []
    end
  end

  defp do_reduce([], state) do
    state
  end

  defp do_reduce(rows, state) do
    new_state = maybe_empty!(state)
    :ets.insert(@table, rows)
    new_state
  end

  defp map_parent_stations(stop_ids) do
    stop_ids
    |> State.Stop.by_ids()
    |> Enum.map(&stop_id_or_parent/1)
  end

  defp stop_id_or_parent(%{parent_station: nil, id: id}), do: id
  defp stop_id_or_parent(%{parent_station: id}), do: id

  @spec merge_ids([stop_id_list]) :: stop_id_list
  @spec merge_ids([stop_id_list], [stop_id_list]) :: stop_id_list
  def merge_ids(lists_of_ids, override_lists \\ [])

  def merge_ids([], _), do: []

  def merge_ids(lists_of_ids, override_lists) do
    sorted_lists = Enum.sort_by(lists_of_ids, &list_merge_key/1, &>=/2)
    # overrides should be short or empty, so putting that first with ++ is
    # fine.
    lists_with_overrides = override_lists ++ sorted_lists

    lists_with_overrides
    |> Enum.reduce(&merge_two_lists/2)
    |> Enum.uniq()
  end

  @spec list_merge_key(stop_id_list) ::
          {non_neg_integer, Model.Stop.id() | nil, Model.Stop.id() | nil}
  defp list_merge_key(list_of_ids) do
    # returns a tuple of {length, first stop id, last stop id}
    Enum.reduce(list_of_ids, {0, nil, nil}, fn id, {count, first_id, _last_id} ->
      {count + 1, first_id || id, id}
    end)
  end

  defp merge_two_lists(one, []), do: one
  defp merge_two_lists([], two), do: two

  defp merge_two_lists(one, two) do
    one
    |> List.myers_difference(two)
    |> merge_differences
  end

  defp merge_differences(diff_list, side \\ :front)

  defp merge_differences([{:del, del}, {:ins, ins} | rest], :front = side) do
    # del is the shorter branch, so put that second if we're on the front side
    ins ++ del ++ merge_differences(rest, side)
  end

  defp merge_differences([{:eq, items} | rest], _side) do
    # once we hit an equal chunk, we're on the back
    items ++ merge_differences(rest, :back)
  end

  defp merge_differences([{_cmd, items} | rest], side) do
    items ++ merge_differences(rest, side)
  end

  defp merge_differences([], _side) do
    []
  end

  defp maybe_empty!(:full) do
    true = @table |> :ets.delete_all_objects()
    :empty
  end

  defp maybe_empty!(:empty) do
    :empty
  end
end
