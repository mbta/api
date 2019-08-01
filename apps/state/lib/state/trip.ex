defmodule State.Trip do
  @moduledoc """
  Stores and indexes `Model.Trip.t` generated from `multi_route_trips.txt` and `trips.txt`.
  """

  use State.Server,
    indices: [:id, :route_id, :route_pattern_id],
    recordable: Model.Trip

  alias Events.Gather
  alias Model.{Direction, MultiRouteTrip, Route, Trip}
  alias State.ServiceByDate
  alias State.Trip.Added

  @type direction_id :: Direction.id() | nil
  @type filter_opts :: %{
          optional(:routes) => [String.t()],
          optional(:direction_id) => direction_id,
          optional(:date) => Date.t(),
          optional(:route_patterns) => [String.t()]
        }

  @fetch_trips {:fetch, "trips.txt"}
  @fetch_multi_route_trips {:fetch, "multi_route_trips.txt"}
  @subscriptions [@fetch_multi_route_trips, @fetch_trips, {:new_state, State.Service}]

  @spec by_primary_id(Trip.id()) :: Trip.t() | nil
  def by_primary_id(id) do
    [id]
    |> by_ids
    |> Enum.find(&Trip.primary?/1)
  end

  @spec by_primary_ids([Trip.id()]) :: [Trip.t()]
  def by_primary_ids(ids) do
    ids
    |> by_ids
    |> Enum.filter(&Trip.primary?/1)
  end

  def by_ids(ids) do
    trips = [
      super(ids),
      Added.by_ids(ids)
    ]

    Enum.concat(trips)
  end

  @doc """
  Applies a filtered search on trips based on a map of filter values.

  The allowed filterable keys are:
    :ids
    :routes
    :direction_id
    :route_patterns
    :date

  If filtering for :date or :direction_id then some other filter must also
  be applied for this filter to apply.

  """
  @spec filter_by(filter_opts) :: [Trip.t()]
  def filter_by(filters)

  def filter_by(filters) do
    filters
    |> build_query()
    |> query_both()
    |> Stream.map(&replace_alternate_trips(&1))
    |> Stream.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.id)
  end

  # Test only
  @doc false
  def reset_gather do
    GenServer.call(__MODULE__, :reset_gather)
  end

  @impl Events.Server
  def handle_event(event, value, _, state) do
    state = %{state | data: Gather.update(state.data, event, value)}
    {:noreply, state, :hibernate}
  end

  @impl GenServer
  def init(_) do
    {:ok, state, timeout_or_hibernate} = super(nil)

    Enum.each(@subscriptions, &subscribe/1)

    data = Gather.new(@subscriptions, &do_gather/1)
    overridden_state = %{state | data: data}
    {:ok, overridden_state, timeout_or_hibernate}
  end

  @impl GenServer
  def handle_call(:reset_gather, _from, state) do
    state = %{state | data: Gather.new(@subscriptions, &do_gather/1)}
    {:reply, :ok, state}
  end

  def handle_call(request, from, state), do: super(request, from, state)

  @impl State.Server
  def handle_new_state(%{multi_route_trips: multi_route_trips, trips: primary_trips}) do
    # Gather added routes first as trips with without `Model.Trip.t`
    # `:alternate_route` is ternary and so none vs 1 is significant:
    #
    # 1. `nil` - no alternates
    # 2. `true` - this is an alternate route trip
    # 3. `false` - this is the primary route trip for a trip that has alternates
    added_route_ids_by_trip_id =
      multi_route_trips_to_added_route_ids_by_trip_id(multi_route_trips)

    primary_trips
    |> flat_map_multi_route_trips(added_route_ids_by_trip_id: added_route_ids_by_trip_id)
    |> super()
  end

  def handle_new_state(other) do
    super(other)
  end

  defp do_gather(%{
         @fetch_trips => parsable_trips,
         @fetch_multi_route_trips => parsable_multi_route_trips
       }) do
    multi_route_trips = Parse.MultiRouteTrips.parse(parsable_multi_route_trips)
    trips = Parse.Trips.parse(parsable_trips)

    handle_new_state(%{multi_route_trips: multi_route_trips, trips: trips})
  end

  defp flat_map_multi_route_trips(primary_trips, keywords) do
    added_route_ids_by_trip_id = Keyword.fetch!(keywords, :added_route_ids_by_trip_id)

    Enum.flat_map(primary_trips, fn primary_trip = %Trip{id: id} ->
      case Map.fetch(added_route_ids_by_trip_id, id) do
        {:ok, added_route_ids} ->
          create_alternates(primary_trip, added_route_ids)

        :error ->
          [primary_trip]
      end
    end)
  end

  defp create_alternates(trip, alternate_routes) do
    new_alternates =
      for route_id <- alternate_routes, route_id != trip.route_id do
        %{trip | route_id: route_id, alternate_route: true}
      end

    new_trip = %{trip | alternate_route: false}
    [new_trip | new_alternates]
  end

  defp build_query(filters, query \\ %{})

  defp build_query(%{direction_id: direction_id} = filters, query) do
    filters = Map.delete(filters, :direction_id)
    query = Map.put(query, :direction_id, [direction_id])
    build_query(filters, query)
  end

  defp build_query(%{date: date} = filters, query) do
    filters = Map.delete(filters, :date)
    service_ids = ServiceByDate.by_date(date)
    query = Map.put(query, :service_id, service_ids)
    build_query(filters, query)
  end

  defp build_query(%{routes: routes} = filters, query) do
    filters = Map.delete(filters, :routes)
    query = Map.put(query, :route_id, routes)
    build_query(filters, query)
  end

  defp build_query(%{route_patterns: routes} = filters, query) do
    filters = Map.delete(filters, :route_patterns)
    query = Map.put(query, :route_pattern_id, routes)
    build_query(filters, query)
  end

  defp build_query(%{names: names} = filters, query) do
    filters = Map.delete(filters, :names)
    query = Map.put(query, :name, names)
    build_query(filters, query)
  end

  defp build_query(%{ids: ids} = filters, query) do
    filters = Map.delete(filters, :ids)
    query = Map.put(query, :id, ids)
    build_query(filters, query)
  end

  defp build_query(_, query) do
    query
  end

  defp query_both(query) do
    State.Trip.Added.query(query) ++ State.Trip.query(query)
  end

  @spec multi_route_trips_to_added_route_ids_by_trip_id([MultiRouteTrip.t()]) :: %{
          Trip.id() => [Route.id(), ...]
        }
  defp multi_route_trips_to_added_route_ids_by_trip_id(multi_route_trips)
       when is_list(multi_route_trips) do
    Enum.reduce(multi_route_trips, %{}, fn %MultiRouteTrip{
                                             added_route_id: route_id,
                                             trip_id: trip_id
                                           },
                                           acc ->
      update_in(acc, [Access.key(trip_id, [])], fn route_ids -> [route_id | route_ids] end)
    end)
  end

  defp replace_alternate_trips(%{alternate_route: true, id: id}) do
    by_primary_id(id)
  end

  defp replace_alternate_trips(trip), do: trip
end
