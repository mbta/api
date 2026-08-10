defmodule State.StopEvent do
  @moduledoc """
  State for stop events - actual arrival/departure times of vehicles at stops
  """
  use State.Server,
    indices: [:id, :trip_id, :stop_id, :route_id, :vehicle_id],
    parser: Parse.StopEvents,
    recordable: Model.StopEvent,
    table_type: :set

  alias Model.Route
  alias Model.Stop
  alias Model.StopEvent
  alias Model.Trip
  alias Model.Vehicle

  @type filters :: %{
          optional(:trip_ids) => [Trip.id()],
          optional(:stop_ids) => [Stop.id()],
          optional(:route_ids) => [Route.id()],
          optional(:vehicle_ids) => [Vehicle.id()],
          optional(:direction_id) => Model.Direction.id()
        }

  # Filter keys ordered by typical selectivity (most selective first)
  @index_keys [:trip_ids, :vehicle_ids, :stop_ids, :route_ids]

  @impl State.Server
  def handle_new_state(binary) when is_binary(binary) do
    # Get the maximum timestamp from existing data
    max_timestamp = get_max_timestamp()

    # Parse with timestamp filtering if we have existing data
    opts = if max_timestamp, do: [newer_than: max_timestamp], else: []

    parsed_data =
      try do
        Parse.StopEvents.parse(binary, opts)
      rescue
        e -> State.Server.log_parse_error(__MODULE__, e)
      end

    # Only proceed with update if parsing succeeded
    case parsed_data do
      nil -> :ok
      data -> super(data)
    end
  end

  def handle_new_state(data), do: super(data)

  @impl State.Server
  def post_commit_hook do
    evict_old_records()
    :ok
  end

  @doc """
  Evicts records older than the configured retention period.

  ## Parameters

    * `retention_seconds` - Number of seconds to retain records. Defaults to
       7200 seconds / 2 hours). Records with timestamps older than `now -
       retention_seconds` will be deleted.

  ## Examples

      # Use default retention period (2 hours)
      evict_old_records()

      # Use custom retention period (1 hour)
      evict_old_records(3600)

  """
  @spec evict_old_records() :: :ok
  def evict_old_records do
    evict_old_records(get_retention_seconds())
  end

  @spec evict_old_records(non_neg_integer()) :: :ok
  def evict_old_records(retention_seconds) when retention_seconds >= 0 do
    cutoff = System.system_time(:second) - retention_seconds
    match_spec = build_eviction_match_spec(cutoff)

    __MODULE__
    |> :mnesia.dirty_select(match_spec)
    |> Enum.each(&:mnesia.transaction(fn -> :mnesia.delete(__MODULE__, &1, :write) end))

    :ok
  end

  defp build_eviction_match_spec(cutoff) do
    fields = StopEvent.fields()
    timestamp_pos = Enum.find_index(fields, &(&1 == :timestamp))
    id_pos = Enum.find_index(fields, &(&1 == :id))

    pattern =
      :_
      |> List.duplicate(length(fields))
      |> List.replace_at(timestamp_pos, :"$1")
      |> List.replace_at(id_pos, :"$2")
      |> then(&[StopEvent | &1])
      |> List.to_tuple()

    # Match spec format: {pattern, guards, result}
    [{pattern, [{:andalso, {:"/=", :"$1", nil}, {:<, :"$1", cutoff}}], [:"$2"]}]
  end

  # Get the maximum timestamp from existing data in the table.
  # Uses a dynamic match spec based on the StopEvent struct to avoid brittleness
  # from hardcoded field positions.
  defp get_max_timestamp do
    # Mnesia records are tuples of {RecordName, field1, field2, ...} where
    # fields follow Recordable declaration order (from StopEvent.fields/0).
    fields = StopEvent.fields()
    timestamp_position = Enum.find_index(fields, &(&1 == :timestamp))

    unless timestamp_position do
      raise "timestamp field not found in StopEvent struct"
    end

    # Build tuple pattern: {StopEvent, :_, :_, ..., :"$1"} with $1 at timestamp's position
    wildcards = List.duplicate(:_, length(fields))
    pattern_list = [StopEvent | List.replace_at(wildcards, timestamp_position, :"$1")]
    pattern = List.to_tuple(pattern_list)

    match_spec = [{pattern, [], [:"$1"]}]

    case :mnesia.dirty_select(__MODULE__, match_spec) do
      [] ->
        nil

      timestamps ->
        timestamps
        |> Enum.reject(&is_nil/1)
        |> Enum.max(fn -> nil end)
    end
  end

  defp get_retention_seconds do
    :state
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:retention_seconds, 7200)
  end

  @spec by_id(String.t()) :: StopEvent.t() | nil
  def by_id(id) do
    case super(id) do
      [] -> nil
      [stop_event] -> stop_event
    end
  end

  @doc """
  Filters stop events based on the provided filter criteria.

  At least one filter should be provided for efficient querying. The function
  automatically selects the most selective index based on the number of values
  in each filter list.

  ## Options

  Accepts the same options as `State.all/2`:
    * `:limit` - Maximum number of results to return
    * `:offset` - Number of results to skip
    * `:order_by` - Field(s) to sort by, e.g. `{:arrived, :asc}`

  ## Examples

      filter_by(%{trip_ids: ["trip1"]})
      filter_by(%{route_ids: ["Red"], direction_id: 0}, limit: 10)

  """
  @spec filter_by(filters(), Keyword.t()) ::
          [StopEvent.t()] | {[StopEvent.t()], State.Pagination.Offsets.t()}
  def filter_by(filters, opts \\ [])

  def filter_by(%{} = filters, _opts) when map_size(filters) == 0 do
    []
  end

  def filter_by(filters, opts) do
    filters
    |> do_indexed_search()
    |> do_post_filters(filters)
    |> State.all(opts)
  end

  # Perform indexed search using best available index
  defp do_indexed_search(filters) do
    case select_best_index(filters) do
      :empty_filter ->
        []

      :no_filters ->
        all()

      {:single_filter, filter_key, values} ->
        fetch_by_index(values, filter_key)

      {:multi_filter, primary_key, primary_values, remaining_indexed} ->
        primary_values
        |> fetch_by_index(primary_key)
        |> apply_indexed_filters(remaining_indexed)
    end
  end

  # Selects the best index based on filter selectivity (smallest list first)
  defp select_best_index(filters) do
    # Check for empty list filters that should return no results
    empty_list_filter? =
      if Enum.any?(@index_keys, &match?([], Map.get(filters, &1))) do
        true
      else
        false
      end

    if empty_list_filter? do
      :empty_filter
    else
      indexed_filters =
        @index_keys
        |> Enum.map(fn key -> {key, Map.get(filters, key)} end)
        |> Enum.filter(fn {_key, values} -> is_list(values) and values != [] end)
        |> Enum.sort_by(fn {_key, values} -> length(values) end)

      case indexed_filters do
        [] ->
          :no_filters

        [{key, values}] ->
          {:single_filter, key, values}

        [{primary_key, primary_values} | rest] ->
          {:multi_filter, primary_key, primary_values, Enum.into(rest, %{})}
      end
    end
  end

  # Fetch records using the appropriate index
  defp fetch_by_index(values, :trip_ids), do: by_trip_ids(values)
  defp fetch_by_index(values, :stop_ids), do: by_stop_ids(values)
  defp fetch_by_index(values, :route_ids), do: by_route_ids(values)
  defp fetch_by_index(values, :vehicle_ids), do: by_vehicle_ids(values)

  defp apply_indexed_filters(events, filters) when map_size(filters) == 0, do: events

  # Apply remaining indexed filters using pre-computed MapSets
  defp apply_indexed_filters(events, filters) do
    filter_specs =
      [trip_ids: :trip_id, stop_ids: :stop_id, route_ids: :route_id, vehicle_ids: :vehicle_id]
      |> Enum.reduce([], fn {filter_key, field}, specs ->
        case filters[filter_key] do
          values when is_list(values) and values != [] ->
            [{:set, field, MapSet.new(values)} | specs]

          _ ->
            specs
        end
      end)

    Enum.filter(events, fn event ->
      Enum.all?(filter_specs, &matches_filter?(event, &1))
    end)
  end

  # Pattern match on filter predicate and argument type
  defp matches_filter?(event, {:set, field, set}),
    do: MapSet.member?(set, Map.get(event, field))

  defp matches_filter?(event, {:eq, field, value}),
    do: Map.get(event, field) == value

  # Apply non-indexed filters after indexed search
  defp do_post_filters(events, %{direction_id: direction_id} = filters) do
    events
    |> Enum.filter(&matches_filter?(&1, {:eq, :direction_id, direction_id}))
    |> do_post_filters(Map.delete(filters, :direction_id))
  end

  defp do_post_filters(events, _filters), do: events
end
