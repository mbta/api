defmodule State.Prediction do
  @moduledoc "State for Predictions"
  use State.Server,
    indices: [:stop_id, :trip_id, :route_id, :route_pattern_id],
    parser: Parse.TripUpdates,
    recordable: Model.Prediction,
    hibernate: false

  import State.Route, only: [by_types: 1]

  def filter_by_route_type(predictions, nil), do: predictions
  def filter_by_route_type(predictions, []), do: predictions

  def filter_by_route_type(predictions, route_types) do
    route_ids =
      route_types
      |> by_types()
      |> MapSet.new(& &1.id)

    Enum.filter(predictions, &(&1.route_id in route_ids))
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
    %{
      trip_id: [schedule.trip_id],
      stop_sequence: [schedule.stop_sequence],
      service_id: State.ServiceByDate.by_date(date)
    }
    |> query()
    |> List.first()
  end

  @spec prediction_for_many([Model.Schedule.t()], Date.t()) :: map
  def prediction_for_many(schedules, %Date{} = date) do
    %{
      trip_id: Enum.map(schedules, & &1.trip_id),
      stop_sequence: Enum.map(schedules, & &1.stop_sequence),
      service_id: State.ServiceByDate.by_date(date)
    }
    |> query()
    |> Map.new(&{{&1.trip_id, &1.stop_sequence}, &1})
  end
end
