defmodule ApiWeb.StopEventView do
  use ApiWeb.Web, :api_view

  location(:stop_event_location)

  def stop_event_location(stop_event, conn),
    do: stop_event_path(conn, :show, stop_event.id)

  attributes([
    :start_date,
    :direction_id,
    :revenue,
    :stop_sequence,
    :arrived,
    :departed
  ])

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

  def arrived(%{arrived: nil}, _conn), do: nil
  def arrived(%{arrived: %DateTime{} = dt}, _conn), do: DateTime.to_iso8601(dt)

  def departed(%{departed: nil}, _conn), do: nil
  def departed(%{departed: %DateTime{} = dt}, _conn), do: DateTime.to_iso8601(dt)

  @doc """
  Preloads relationships for stop events when requested via ?include=* to prevent N+1 queries.

  For schedules, pre-formats the times using each stop_event's start_date to avoid
  assigning incorrect times when multiple stop_events have different dates.
  """
  def preload(stop_events, conn, include_opts) when is_list(stop_events) do
    stop_events
    |> super(conn, include_opts)
    |> attach_schedules_if_needed(conn)
  end

  def preload(stop_event, conn, _opts) do
    attach_schedules_if_needed(stop_event, conn)
  end

  defp attach_schedules_if_needed(stop_events, conn) when is_list(stop_events) do
    if split_included?("schedule", conn) do
      schedules = State.Schedule.schedule_for_many(stop_events)

      Enum.map(stop_events, fn stop_event ->
        schedule = Map.get(schedules, {stop_event.trip_id, stop_event.stop_sequence})
        attach_formatted_schedule(stop_event, schedule)
      end)
    else
      stop_events
    end
  end

  defp attach_schedules_if_needed(stop_event, conn) do
    if split_included?("schedule", conn) do
      schedule = State.Schedule.schedule_for(stop_event)
      attach_formatted_schedule(stop_event, schedule)
    else
      stop_event
    end
  end

  defp attach_formatted_schedule(stop_event, schedule) do
    formatted = if schedule, do: format_schedule_times(schedule, stop_event.start_date)
    Map.put(stop_event, :schedule, formatted)
  end

  defp format_schedule_times(schedule, start_date) do
    schedule
    |> Map.put(:arrival_time, format_time_value(schedule.arrival_time, start_date))
    |> Map.put(:departure_time, format_time_value(schedule.departure_time, start_date))
  end

  defp format_time_value(seconds, start_date) when is_integer(seconds) do
    start_date
    |> DateHelpers.add_seconds_to_date(seconds)
    |> DateTime.to_iso8601()
  end

  defp format_time_value(nil, _start_date), do: nil

  defp format_time_value(already_formatted, _start_date) when is_binary(already_formatted),
    do: already_formatted

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
