defmodule ApiWeb.TransferView do
  use ApiWeb.Web, :api_view

  attributes([
    :min_transfer_time,
    :min_walk_time,
    :min_wheelchair_time,
    :suggested_buffer_time,
    :transfer_type,
    :wheelchair_transfer
  ])

  has_one(
    :from_stop,
    type: :stop,
    serializer: ApiWeb.StopView,
    field: :from_stop_id
  )

  has_one(
    :to_stop,
    type: :stop,
    serializer: ApiWeb.StopView,
    field: :to_stop_id
  )

  has_one(
    :from_trip,
    type: :trip,
    serializer: ApiWeb.TripView,
    field: :from_trip_id
  )

  has_one(
    :to_trip,
    type: :trip,
    serializer: ApiWeb.TripView,
    field: :to_trip_id
  )

  def id(
        %{
          from_trip_id: from_trip_id,
          from_stop_id: from_stop_id,
          to_trip_id: to_trip_id,
          to_stop_id: to_stop_id
        },
        _conn
      ) do
    from_trip = from_trip_id || ""
    to_trip = to_trip_id || ""
    from_route = route_id(from_trip)
    to_route = route_id(to_trip)

    "transfer-" <>
      from_trip <>
      "-" <>
      from_route <>
      "-" <> from_stop_id <> "-" <> to_trip <> "-" <> to_route <> "-" <> to_stop_id
  end

  defp route_id(""), do: ""

  defp route_id(trip_id) do
    case State.Trip.by_primary_id(trip_id) do
      [%Model.Trip{route_id: route_id}] when is_binary(route_id) -> route_id
      _ -> ""
    end
  end
end
