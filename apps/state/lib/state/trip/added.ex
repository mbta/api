defmodule State.Trip.Added do
  @moduledoc """

  State for added trips.  They aren't matched to GTFS trip IDs, so we
  maintain them separately, based on the predictions we see.

  """
  use State.Server,
    indices: [:id, :route_id],
    recordable: Model.Trip,
    hibernate: false

  alias Model.{Prediction, Trip}

  @impl GenServer
  def init(state) do
    subscribe({:new_state, State.Prediction})
    super(state)
  end

  @impl Events.Server
  def handle_event(_, _, _, state) do
    handle_new_state(&build_state/0)
    {:noreply, state}
  end

  @spec build_state :: Enumerable.t()
  defp build_state do
    [%{trip_match?: false}]
    |> State.Prediction.select()
    |> predictions_to_trips()
  end

  def predictions_to_trips(predictions) do
    predictions
    |> Stream.reject(&(is_nil(&1.trip_id) or is_nil(&1.stop_id)))
    |> Enum.reduce(%{}, &last_stop_prediction/2)
    |> Stream.flat_map(&prediction_to_trip/1)
  end

  @spec last_stop_prediction(Prediction.t(), acc) :: acc
        when acc: %{optional(Trip.id()) => Prediction.t()}
  defp last_stop_prediction(prediction, acc) do
    # remember the last prediction for the given trip
    Map.update(acc, prediction.trip_id, prediction, fn old ->
      if old.stop_sequence > prediction.stop_sequence do
        old
      else
        prediction
      end
    end)
  end

  @spec prediction_to_trip({Trip.id(), Prediction.t()}) :: [Trip.t()]
  defp prediction_to_trip({trip_id, prediction}) do
    stop =
      case State.Stop.by_id(prediction.stop_id) do
        %{parent_station: nil} = stop -> stop
        %{parent_station: id} -> State.Stop.by_id(id)
        _other -> nil
      end

    last_stop_id =
      [prediction.route_id]
      |> State.Shape.select_routes(prediction.direction_id)
      |> Enum.filter(&(&1.route_id == prediction.route_id))
      |> Enum.find_value(&last_stop_on_shape(&1, prediction, stop))

    stop =
      if is_nil(last_stop_id) or last_stop_id == stop.id do
        stop
      else
        State.Stop.by_id(last_stop_id)
      end

    if stop == nil do
      []
    else
      route = State.Route.by_id(prediction.route_id)

      [
        %Trip{
          id: trip_id,
          route_id: prediction.route_id,
          route_pattern_id: prediction.route_pattern_id,
          direction_id: prediction.direction_id,
          route_type: if(route, do: route.type),
          wheelchair_accessible: 0,
          headsign: stop.name,
          name: "",
          bikes_allowed: 0
        }
      ]
    end
  end

  defp last_stop_on_shape(%{priority: p} = shape, prediction, stop) when p >= 0 do
    shape_stops =
      State.StopsOnRoute.by_route_id(
        prediction.route_id,
        direction_id: prediction.direction_id,
        shape_ids: [shape.id],
        include_alternates?: false
      )

    if Enum.any?(shape_stops, &(&1 == stop.id)) do
      List.last(shape_stops)
    end
  end

  defp last_stop_on_shape(_, _, _) do
    nil
  end
end
