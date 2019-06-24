defmodule State.Schedule do
  @moduledoc "State for Schedules"

  use State.Server,
    indicies: [:trip_id, :stop_id],
    recordable: Model.Schedule

  require Logger
  alias Events.Gather
  alias Model.Schedule
  alias Parse.StopTimes
  alias State.Trip

  @fetch_stop_times {:fetch, "stop_times.txt"}
  @subscriptions [@fetch_stop_times, {:new_state, Trip}]

  @type filter_opts :: %{
          optional(:routes) => [Model.Route.id()],
          optional(:trips) => [Model.Trip.id()],
          optional(:direction_id) => Model.Direction.id(),
          optional(:stops) => [Model.Stop.id()],
          optional(:stop_sequence) => stop_sequence,
          optional(:date) => Date.t(),
          optional(:min_time) => non_neg_integer,
          optional(:max_time) => non_neg_integer
        }

  @typep convert_filters :: %{
           optional(:routes) => [Model.Route.id()],
           optional(:trips) => [Model.Trip.id()],
           optional(:direction_id) => Model.Direction.id(),
           optional(:stops) => [Model.Stop.id()],
           optional(:date) => Date.t()
         }

  @typep min_time :: non_neg_integer
  @typep max_time :: non_neg_integer | :infinity

  @typep search :: %{
           index: :stop_id | :trip_id,
           matchers: [%{}]
         }

  @typep stop_sequence_item :: non_neg_integer | :first | :last
  @typep stop_sequence :: [stop_sequence_item]
  @typep stop_sequence_matcher :: State.Matchers.stop_sequence_matcher()

  @doc """
  Applies a filtered search on Schedules based on a map of filters values.

  The allowed filterable keys are:
    :routes
    :direction_id
    :trips
    :stop_sequence
    :stops
    :min_time
    :max_time
    :date

  At least one of the following filters must be applied for any schedules to
  returned:
    :routes
    :trips
    :stops

  ### Important Behavior Notes

  When filtering on both `:routes` and `:trips`, `:routes` has priority for
  filtering.

  When filtering with `:direction_id`, either `:routes` or `:stops` must also
  be applied.

  When filtering with `:date`, either `:routes` or `:stops` must also be
  applied.
  """
  @spec filter_by(filter_opts) :: [Schedule.t()]
  def filter_by(filters) do
    filters
    |> convert_filters()
    |> build_filter_matchers()
    |> do_filtered_search(filters)
    |> do_post_search_filter(filters)
  end

  # Only for tests
  @doc false
  def reset_gather do
    GenServer.call(__MODULE__, :reset_gather)
  end

  @spec schedule_for(Model.Prediction.t()) :: Model.Schedule.t() | nil
  def schedule_for(%Model.Prediction{} = prediction) do
    stop_ids =
      case State.Stop.siblings(prediction.stop_id) do
        [_ | _] = stops -> Enum.map(stops, & &1.id)
        [] -> [prediction.stop_id]
      end

    %{
      trips: [prediction.trip_id],
      stops: stop_ids,
      stop_sequence: [prediction.stop_sequence]
    }
    |> filter_by
    |> List.first()
  end

  @spec build_stop_sequence_matchers(stop_sequence | nil) :: [stop_sequence_matcher]
  def build_stop_sequence_matchers(nil), do: [%{}]
  def build_stop_sequence_matchers([]), do: [%{}]

  def build_stop_sequence_matchers(stop_sequence) do
    Enum.map(stop_sequence, &State.Matchers.stop_sequence/1)
  end

  @impl Events.Server
  def handle_event(event, value, _, state) do
    state = %{state | data: Gather.update(state.data, event, value)}
    {:noreply, state, :hibernate}
  end

  # Only for tests
  @impl GenServer
  def handle_call(:reset_gather, _from, state) do
    state = %{state | data: Gather.new(@subscriptions, &do_gather/1)}
    {:reply, :ok, state}
  end

  def handle_call(request, from, state), do: super(request, from, state)

  @impl GenServer
  def init(_) do
    {:ok, state, timeout_or_hibernate} = super(nil)

    Enum.each(@subscriptions, &subscribe/1)

    data = Gather.new(@subscriptions, &do_gather/1)
    overridden_state = %{state | data: data}
    {:ok, overridden_state, timeout_or_hibernate}
  end

  # Converts routes and stops into workable ids
  @spec convert_filters(filter_opts) :: convert_filters
  defp convert_filters(%{routes: _} = filters) do
    # Routes have priority for filtering on trip ids
    # Modify :trips in the filters with the trip ids based on the route ids

    trips_ids =
      filters
      |> Map.take([:routes, :direction_id, :date])
      |> State.Trip.filter_by()
      |> Enum.map(& &1.id)

    filters
    |> Map.delete(:routes)
    |> Map.put(:trips, trips_ids)
    |> convert_filters()
  end

  defp convert_filters(%{stops: stop_ids} = filters) do
    stops = stops_by_family_ids(stop_ids)
    Map.put(filters, :stops, stops)
  end

  defp convert_filters(filters), do: filters

  # Build search criteria
  @spec build_filter_matchers(convert_filters) :: search | %{}
  defp build_filter_matchers(%{stops: stops, trips: trips} = filters) do
    stop_sequence_matchers = build_stop_sequence_matchers(filters[:stop_sequence])

    all_trips = State.Trip.by_ids(trips)
    routes_from_trips = MapSet.new(all_trips, & &1.route_id)

    filtered_routes =
      stops
      |> State.RoutesAtStop.by_stops_and_direction()
      |> MapSet.new()
      |> MapSet.intersection(routes_from_trips)

    filtered_trips =
      all_trips
      |> Stream.filter(&Enum.member?(filtered_routes, &1.route_id))
      |> Enum.map(& &1.id)

    matchers =
      for stop_id <- stops,
          trip_id <- filtered_trips,
          stop_sequence_matcher <- stop_sequence_matchers do
        stop_sequence_matcher
        |> Map.put(:trip_id, trip_id)
        |> Map.put(:stop_id, stop_id)
      end

    %{index: :trip_id, matchers: matchers}
  end

  defp build_filter_matchers(%{stops: stops} = filters) do
    direction_matcher = State.Matchers.direction_id(filters[:direction_id])
    stop_sequence_matchers = build_stop_sequence_matchers(filters[:stop_sequence])

    matchers =
      for stop_id <- stops,
          stop_sequence_matcher <- stop_sequence_matchers do
        stop_sequence_matcher
        |> Map.put(:stop_id, stop_id)
        |> Map.merge(direction_matcher)
      end

    %{index: :stop_id, matchers: matchers}
  end

  defp build_filter_matchers(%{trips: trips} = filters) do
    stop_sequence_matchers = build_stop_sequence_matchers(filters[:stop_sequence])

    matchers =
      for trip_id <- trips,
          stop_sequence_matcher <- stop_sequence_matchers do
        Map.put(stop_sequence_matcher, :trip_id, trip_id)
      end

    %{index: :trip_id, matchers: matchers}
  end

  defp build_filter_matchers(_), do: %{}

  defp do_gather(%{@fetch_stop_times => blob}) do
    # we parse the blob in the same process as the schedule to prevent copying
    # all the data to a new process. Sending the binary blob sends it by
    # reference, so no copying!
    _ = Logger.debug(fn -> "#{__MODULE__} Parsing and writing schedule data..." end)

    blob
    |> StopTimes.parse(&Trip.by_primary_id/1)
    |> handle_new_state()
  end

  # Performs the search on the given index and matchers
  @spec do_filtered_search(search, filter_opts) :: [Schedule.t()]
  defp do_filtered_search(
         %{index: index, matchers: [_ | _] = matchers},
         filters
       ) do
    schedules = select(matchers, index)

    do_service_date_filter(schedules, filters)
  end

  defp do_filtered_search(_, _), do: []

  # Filters schedules for a given service date
  @spec do_service_date_filter([Schedule.t()], filter_opts) :: [Schedule.t()]
  defp do_service_date_filter(schedules, %{date: %Date{} = date}) do
    Enum.filter(schedules, &State.ServiceByDate.valid?(&1.service_id, date))
  end

  defp do_service_date_filter(schedules, _), do: schedules

  # Apply any filters after a completed search. Currently, only a time window
  # filter is supported
  @spec do_post_search_filter([Schedule.t()], filter_opts) :: [Schedule.t()]
  defp do_post_search_filter(schedules, %{min_time: min, max_time: max}) do
    do_time_filter(schedules, min, max)
  end

  defp do_post_search_filter(schedules, %{min_time: min}) do
    do_time_filter(schedules, min, :infinity)
  end

  defp do_post_search_filter(schedules, %{max_time: max}) do
    do_time_filter(schedules, 0, max)
  end

  defp do_post_search_filter(schedules, _), do: schedules

  # Filters schedules to see if they fit within a time window
  @spec do_time_filter([Schedule.t()], min_time, max_time) :: [Schedule.t()]
  defp do_time_filter(schedules, min_time, max_time) do
    Enum.filter(schedules, &in_time_range?(&1, min_time, max_time))
  end

  @spec in_time_range?(Schedule.t(), min_time, max_time) :: boolean
  defp in_time_range?(schedule, min_time, max_time) do
    time = Schedule.time(schedule)
    min_time <= time and time <= max_time
  end

  @spec stops_by_family_ids([String.t()]) :: [Model.Stop.id()]
  defp stops_by_family_ids(stop_ids) do
    stop_ids
    |> State.Stop.by_family_ids()
    |> Enum.map(& &1.id)
  end
end
