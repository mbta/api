defmodule State.StopEvent do
  @moduledoc """
  State for stop events - actual arrival/departure times of vehicles at stops
  """
  use State.Server,
    indices: [:id, :trip_id, :stop_id, :route_id, :vehicle_id],
    parser: Parse.StopEvents,
    recordable: Model.StopEvent

  alias Model.Route
  alias Model.StopEvent
  alias Model.Stop
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
  @filter_keys [:trip_ids, :vehicle_ids, :stop_ids, :route_ids]

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

  def filter_by(%{} = filters, opts) when map_size(filters) == 0 do
    all()
    |> State.all(opts)
  end

  def filter_by(filters, opts) do
    case select_best_index(filters) do
      {:direction_id_only, direction_id} ->
        # direction_id alone requires full scan
        all()
        |> filter_by_direction(direction_id)
        |> State.all(opts)

      {:single_filter, filter_key, values} ->
        # Single indexed filter - use index directly, no MapSet needed
        values
        |> fetch_by_index(filter_key)
        |> maybe_filter_direction(filters[:direction_id])
        |> State.all(opts)

      {:multi_filter, primary_key, primary_values, remaining_filters} ->
        # Multiple filters - use best index, then apply remaining with MapSets
        primary_values
        |> fetch_by_index(primary_key)
        |> apply_additional_filters(remaining_filters)
        |> State.all(opts)

      :no_filters ->
        []
    end
  end

  # Selects the best index based on filter selectivity (smallest list first)
  defp select_best_index(filters) do
    indexed_filters =
      @filter_keys
      |> Enum.map(fn key -> {key, Map.get(filters, key)} end)
      |> Enum.filter(fn {_key, values} -> is_list(values) and values != [] end)
      |> Enum.sort_by(fn {_key, values} -> length(values) end)

    direction_id = filters[:direction_id]

    case {indexed_filters, direction_id} do
      {[], nil} ->
        :no_filters

      {[], direction_id} ->
        {:direction_id_only, direction_id}

      {[{key, values}], nil} ->
        {:single_filter, key, values}

      {[{key, values}], direction_id} ->
        # Single indexed filter + direction_id
        remaining = %{direction_id: direction_id}
        {:multi_filter, key, values, remaining}

      {[{primary_key, primary_values} | rest], direction_id} ->
        # Multiple indexed filters - build remaining filter map
        remaining =
          rest
          |> Enum.into(%{})
          |> maybe_put_direction(direction_id)

        {:multi_filter, primary_key, primary_values, remaining}
    end
  end

  defp maybe_put_direction(map, nil), do: map
  defp maybe_put_direction(map, direction_id), do: Map.put(map, :direction_id, direction_id)

  # Fetch records using the appropriate index
  defp fetch_by_index(values, :trip_ids), do: by_trip_ids(values)
  defp fetch_by_index(values, :stop_ids), do: by_stop_ids(values)
  defp fetch_by_index(values, :route_ids), do: by_route_ids(values)
  defp fetch_by_index(values, :vehicle_ids), do: by_vehicle_ids(values)

  # Simple direction filter for single-filter cases (no MapSet overhead)
  defp filter_by_direction(events, direction_id) do
    Enum.filter(events, fn %StopEvent{direction_id: d_id} -> d_id == direction_id end)
  end

  defp maybe_filter_direction(events, nil), do: events
  defp maybe_filter_direction(events, direction_id), do: filter_by_direction(events, direction_id)

  # Apply additional filters using pre-computed MapSets (for multi-filter cases)
  defp apply_additional_filters(events, filters) when map_size(filters) == 0, do: events

  defp apply_additional_filters(events, filters) do
    # Build all filter sets upfront to avoid repeated MapSet creation
    filter_specs = build_filter_specs(filters)

    Enum.filter(events, fn event ->
      Enum.all?(filter_specs, fn spec -> matches_filter?(event, spec) end)
    end)
  end

  # Build filter specifications with pre-computed MapSets
  defp build_filter_specs(filters) do
    []
    |> maybe_add_filter_spec(filters[:trip_ids], :trip_id)
    |> maybe_add_filter_spec(filters[:stop_ids], :stop_id)
    |> maybe_add_filter_spec(filters[:route_ids], :route_id)
    |> maybe_add_filter_spec(filters[:vehicle_ids], :vehicle_id)
    |> maybe_add_direction_spec(filters[:direction_id])
  end

  defp maybe_add_filter_spec(specs, nil, _field), do: specs
  defp maybe_add_filter_spec(specs, [], _field), do: specs

  defp maybe_add_filter_spec(specs, values, field) when is_list(values) do
    [{:set, field, MapSet.new(values)} | specs]
  end

  defp maybe_add_direction_spec(specs, nil), do: specs

  defp maybe_add_direction_spec(specs, direction_id),
    do: [{:eq, :direction_id, direction_id} | specs]

  # Pattern match on filter specification type for efficient dispatch
  defp matches_filter?(event, {:set, field, set}) do
    MapSet.member?(set, Map.get(event, field))
  end

  defp matches_filter?(event, {:eq, field, value}) do
    Map.get(event, field) == value
  end
end
