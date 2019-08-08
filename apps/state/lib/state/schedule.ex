defmodule State.Schedule do
  @moduledoc "State for Schedules"

  use State.Server,
    indices: [:trip_id, :stop_id],
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

  @typep min_time :: non_neg_integer
  @typep max_time :: non_neg_integer | :infinity

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
    |> build_query()
    |> query()
    |> do_post_search_filter(filters)
  end

  # Only for tests
  @doc false
  def reset_gather do
    GenServer.call(__MODULE__, :reset_gather)
  end

  @schedule_relationships_with_schedules [nil, :cancelled, :no_data, :skipped]

  @spec schedule_for(Model.Prediction.t()) :: Model.Schedule.t() | nil
  def schedule_for(%Model.Prediction{schedule_relationship: relationship} = prediction)
      when relationship in @schedule_relationships_with_schedules do
    %{
      trip_id: [prediction.trip_id],
      stop_sequence: [prediction.stop_sequence]
    }
    |> query()
    |> List.first()
  end

  def schedule_for(%Model.Prediction{}) do
    nil
  end

  @spec schedule_for_many([Model.Prediction.t()]) :: map
  def schedule_for_many(predictions) do
    queries =
      for prediction <- predictions,
          prediction.schedule_relationship in @schedule_relationships_with_schedules do
        %{
          trip_id: [prediction.trip_id],
          stop_sequence: [prediction.stop_sequence]
        }
      end

    if queries == [] do
      %{}
    else
      queries
      |> query()
      |> Map.new(&{{&1.trip_id, &1.stop_sequence}, &1})
    end
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

  def build_query(_filters, query \\ %{})

  def build_query(%{routes: _route_ids} = filters, query) do
    keys = [:routes, :direction_id, :date]

    trip_ids =
      filters
      |> Map.take(keys)
      |> State.Trip.filter_by()
      |> Enum.map(& &1.id)

    filters = Map.drop(filters, keys)

    {filters, trip_ids} =
      case filters do
        %{trips: other_trip_ids} ->
          # intersection of trip IDs
          trip_ids = trip_ids -- trip_ids -- other_trip_ids
          {Map.delete(filters, :trips), trip_ids}

        %{} ->
          {filters, trip_ids}
      end

    query = Map.put(query, :trip_id, trip_ids)
    build_query(filters, query)
  end

  def build_query(%{stops: stop_ids} = filters, query) do
    filters = Map.delete(filters, :stops)
    query = Map.put(query, :stop_id, State.Stop.location_type_0_ids_by_parent_ids(stop_ids))
    build_query(filters, query)
  end

  def build_query(%{trips: trip_ids} = filters, query) do
    filters = Map.delete(filters, :trips)
    query = Map.put(query, :trip_id, trip_ids)
    build_query(filters, query)
  end

  def build_query(%{direction_id: direction_id} = filters, query) do
    filters = Map.delete(filters, :direction_id)
    query = Map.put(query, :direction_id, List.wrap(direction_id))
    build_query(filters, query)
  end

  def build_query(%{date: date} = filters, query) do
    filters = Map.delete(filters, :date)
    service_ids = State.ServiceByDate.by_date(date)
    query = Map.put(query, :service_id, service_ids)
    build_query(filters, query)
  end

  def build_query(%{stop_sequence: stop_sequences} = filters, query) do
    filters = Map.delete(filters, :stop_sequence)

    values = Enum.group_by(stop_sequences, &is_atom/1)
    positions = Map.get(values, true)
    stop_sequences = Map.get(values, false)

    query =
      if positions do
        Map.put(query, :position, positions)
      else
        query
      end

    query =
      if stop_sequences do
        Map.put(query, :stop_sequence, stop_sequences)
      else
        query
      end

    build_query(filters, query)
  end

  def build_query(_filters, query) do
    query
  end

  defp do_gather(%{@fetch_stop_times => blob}) do
    # we parse the blob in the same process as the schedule to prevent copying
    # all the data to a new process. Sending the binary blob sends it by
    # reference, so no copying!
    _ = Logger.debug(fn -> "#{__MODULE__} Parsing and writing schedule data..." end)

    blob
    |> StopTimes.parse(&Trip.by_primary_id/1)
    |> handle_new_state()
  end

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
end
