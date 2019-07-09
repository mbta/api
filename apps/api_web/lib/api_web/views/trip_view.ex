defmodule ApiWeb.TripView do
  use ApiWeb.Web, :api_view

  alias ApiWeb.{
    PredictionView,
    RoutePatternView,
    RouteView,
    ServiceView,
    ShapeView,
    StopView,
    VehicleView
  }

  alias State.{Prediction, RoutePattern, Schedule, Service, Shape, Stop, Vehicle}

  location("/trips/:id")

  attributes([:name, :headsign, :direction_id, :wheelchair_accessible, :block_id, :bikes_allowed])

  has_one(
    :route,
    type: :route,
    serializer: RouteView
  )

  has_one(
    :shape,
    type: :shape,
    serializer: ShapeView
  )

  has_one(
    :vehicle,
    type: :vehicle,
    serializer: VehicleView
  )

  has_one(
    :service,
    type: :service,
    serializer: ServiceView
  )

  has_one(
    :route_pattern,
    type: :route_pattern,
    serializer: RoutePatternView
  )

  has_many(
    :predictions,
    type: :prediction,
    serializer: PredictionView
  )

  has_many(
    :stops,
    type: :stop,
    serializer: StopView,
    include: false
  )

  def shape(%{shape_id: shape_id}, conn) do
    optional_relationship("shape", shape_id, &Shape.by_primary_id/1, conn)
  end

  def service(%{service_id: service_id}, conn) do
    optional_relationship("service", service_id, &Service.by_id/1, conn)
  end

  def route_pattern(%{route_pattern_id: route_pattern_id}, conn) do
    optional_relationship("route_pattern", route_pattern_id, &RoutePattern.by_id/1, conn)
  end

  def vehicle(%{id: trip_id}, _conn) do
    case Vehicle.by_trip_id(trip_id) do
      [] -> nil
      [vehicle] -> vehicle
    end
  end

  def predictions(%{id: trip_id}, conn) do
    # if we get back the trip_id, then predictions weren't included and we
    # should return nothing
    case optional_predictions(trip_id, conn) do
      %{id: ^trip_id} -> nil
      ret -> ret
    end
  end

  defp optional_predictions(trip_id, conn) do
    optional_relationship(
      "predictions",
      trip_id,
      fn _ ->
        Prediction.by_trip_id(trip_id)
      end,
      conn
    )
  end

  def stops(%{id: trip_id}, conn) do
    stop_ids =
      trip_id
      |> Schedule.by_trip_id()
      |> Enum.sort_by(& &1.stop_sequence)
      |> Enum.map(& &1.stop_id)

    optional_relationship("stops", stop_ids, &Stop.by_ids/1, conn)
  end

  def relationships(trip, conn) do
    relationships = super(trip, conn)

    ~W(predictions vehicle stops)a
    |> Enum.reduce(relationships, fn type_atom, map ->
      if split_included?(Atom.to_string(type_atom), conn) do
        map
      else
        Map.delete(map, type_atom)
      end
    end)
  end
end
