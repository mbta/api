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
    include: true,
    field: :from_stop_id
  )

  has_one(
    :to_stop,
    type: :stop,
    serializer: ApiWeb.StopView,
    include: true,
    field: :to_stop_id
  )

  has_one(
    :from_trip,
    type: :trip,
    serializer: ApiWeb.TripView,
    include: true,
    field: :from_trip_id
  )

  has_one(
    :to_trip,
    type: :trip,
    serializer: ApiWeb.TripView,
    include: true,
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
    "transfer-#{from_trip}-#{from_stop_id}-#{to_trip}-#{to_stop_id}"
  end

  def from_trip(%{from_trip_id: trip_id}, conn) do
    optional_relationship("from_trip", trip_id, &State.Trip.by_primary_id/1, conn)
  end

  def to_trip(%{to_trip_id: trip_id}, conn) do
    optional_relationship("to_trip", trip_id, &State.Trip.by_primary_id/1, conn)
  end

  def from_stop(%{from_stop_id: stop_id}, conn) do
    optional_relationship("from_stop", stop_id, &State.Stop.by_id/1, conn)
  end

  def to_stop(%{to_stop_id: stop_id}, conn) do
    optional_relationship("to_stop", stop_id, &State.Stop.by_id/1, conn)
  end
end
