defmodule State.Prediction do
  @moduledoc "State for Predictions"
  use State.Server,
    indices: [:stop_id, :trip_id, :route_id, :route_pattern_id],
    parser: Parse.TripUpdates,
    recordable: Model.Prediction,
    hibernate: false

  @doc """
  Selects a distinct group of Prediction state sources, with filtering.

  ## Examples

    iex> [
      State.Prediction
    ]
    |> State.Prediction.select_grouped(matchers, index, opts)
    [...]
  """

  import Parse.Time, only: [service_date: 1]
  import State.Route, only: [by_types: 1]

  def select_grouped(sources, matchers, index, opts \\ []) do
    sources
    |> Stream.flat_map(&apply(&1, :select, [matchers, index]))
    |> Enum.uniq_by(&prediction_key/1)
    |> State.all(opts)
  end

  def filter_by_route_type(predictions, nil), do: predictions
  def filter_by_route_type(predictions, []), do: predictions

  def filter_by_route_type(predictions, route_types) do
    route_ids =
      route_types
      |> by_types()
      |> MapSet.new(& &1.id)

    Enum.filter(predictions, &(&1.route_id in route_ids))
  end

  defp prediction_key(%Model.Prediction{stop_sequence: stop_seq} = mod) do
    {stop_seq, mod.stop_id, mod.route_id, mod.trip_id, mod.direction_id}
  end

  @spec by_stop_route(Model.Stop.id(), Model.Route.id()) :: [Model.Prediction.t()]
  def by_stop_route(stop_id, route_id) do
    match(%{stop_id: stop_id, route_id: route_id}, :stop_id)
  end

  @impl State.Server
  def pre_insert_hook(prediction) do
    trips =
      case prediction do
        %{trip_id: trip_id} when is_binary(trip_id) ->
          State.Trip.by_id(trip_id)

        _ ->
          []
      end

    prediction
    |> fill_missing_direction_ids(trips)
    |> update_route_from_alternate_trips(trips)
  end

  defp fill_missing_direction_ids(%{direction_id: direction_id} = prediction, _trips)
       when is_integer(direction_id) do
    prediction
  end

  defp fill_missing_direction_ids(
         prediction,
         trips
       ) do
    case trips do
      [%{direction_id: direction} | _] -> %{prediction | direction_id: direction}
      _ -> prediction
    end
  end

  defp update_route_from_alternate_trips(prediction, [_ | _] = trips) do
    for trip <- trips do
      %{prediction | route_id: trip.route_id, route_pattern_id: trip.route_pattern_id}
    end
  end

  defp update_route_from_alternate_trips(prediction, _trips) do
    [prediction]
  end

  @spec prediction_for(Model.Schedule.t(), Date.t()) :: Model.Prediction.t()
  def prediction_for(%Model.Schedule{} = schedule, %Date{} = date) do
    stop_ids =
      case State.Stop.siblings(schedule.stop_id) do
        [_ | _] = stops -> Enum.map(stops, & &1.id)
        [] -> [schedule.stop_id]
      end

    queries =
      for stop_id <- stop_ids do
        %{
          trip_id: schedule.trip_id,
          stop_id: stop_id,
          stop_sequence: schedule.stop_sequence
        }
      end

    [
      State.Prediction
    ]
    |> State.Prediction.select_grouped(
      queries,
      :stop_id
    )
    |> Enum.find(&on_day?(&1, date))
  end

  @spec prediction_for_many([Model.Schedule.t()], Date.t()) :: map
  def prediction_for_many(schedules, %Date{} = date) do
    Map.new(schedules, &{{&1.trip_id, &1.stop_sequence}, prediction_for(&1, date)})
  end

  @spec on_day?(Model.Prediction.t(), Date.t()) :: boolean()
  defp on_day?(prediction, date) do
    [:arrival_time, :departure_time]
    |> Enum.any?(fn time_key ->
      case Map.get(prediction, time_key) do
        %DateTime{} = dt ->
          dt
          |> service_date
          |> Kernel.==(date)

        nil ->
          false
      end
    end)
  end
end
