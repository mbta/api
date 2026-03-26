defmodule State.StopEvent do
  @moduledoc """
  State for stop events - actual arrival/departure times of vehicles at stops
  """
  use State.Server,
    indices: [:id, :trip_id, :stop_id, :route_id, :vehicle_id],
    recordable: Model.StopEvent

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
