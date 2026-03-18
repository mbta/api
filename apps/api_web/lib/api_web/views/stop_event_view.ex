defmodule ApiWeb.StopEventView do
  use ApiWeb.Web, :api_view

  has_one(
    :trip,
    type: :trip,
    serializer: ApiWeb.TripView,
    field: :trip_id
  )

  has_one(
    :stop,
    type: :stop,
    serializer: ApiWeb.StopView,
    field: :stop_id
  )

  has_one(
    :route,
    type: :route,
    serializer: ApiWeb.RouteView,
    field: :route_id
  )

  has_one(
    :vehicle,
    type: :vehicle,
    serializer: ApiWeb.VehicleView,
    field: :vehicle_id
  )

  attributes([
    :vehicle_id,
    :start_date,
    :trip_id,
    :direction_id,
    :route_id,
    :revenue,
    :stop_id,
    :stop_sequence,
    :arrived,
    :departed
  ])

  def arrived(%{arrived: nil}, _conn), do: nil
  def arrived(%{arrived: %DateTime{} = dt}, _conn), do: DateTime.to_iso8601(dt)

  def departed(%{departed: nil}, _conn), do: nil
  def departed(%{departed: %DateTime{} = dt}, _conn), do: DateTime.to_iso8601(dt)

  @doc """
  Preloads schedule relationships for stop events when requested via ?include=schedule to prevent N+1 queries.
  """
  def preload(stop_events, conn, _opts) when is_list(stop_events) do
    if split_included?("schedule", conn) do
      schedules = State.Schedule.schedule_for_many(stop_events)

      Enum.map(stop_events, fn stop_event ->
        schedule = Map.get(schedules, {stop_event.trip_id, stop_event.stop_sequence})
        Map.put(stop_event, :schedule, schedule)
      end)
    else
      stop_events
    end
  end

  def preload(stop_event, conn, _opts) do
    if split_included?("schedule", conn) do
      schedule = State.Schedule.schedule_for(stop_event)
      Map.put(stop_event, :schedule, schedule)
    else
      stop_event
    end
  end

  def relationships(stop_event, conn) do
    # Get the base relationships as a map from has_one macros
    base_relationships = super(stop_event, conn)

    if split_included?("schedule", conn) do
      Map.put(
        base_relationships,
        :schedule,
        %HasOne{
          type: :schedule,
          name: :schedule,
          data: schedule(stop_event, conn),
          serializer: ApiWeb.ScheduleView
        }
      )
    else
      base_relationships
    end
  end

  defp schedule(%{schedule: schedule}, _conn), do: schedule

  defp schedule(stop_event, conn),
    do: optional_relationship("schedule", stop_event, &State.Schedule.schedule_for/1, conn)
end
