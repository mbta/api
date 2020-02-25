defmodule ApiWeb.ScheduleView do
  use ApiWeb.Web, :api_view
  alias ApiWeb.Plugs.Deadline
  alias JaSerializer.Relationship.HasOne

  def relationships(_, _) do
    %{
      stop: %HasOne{type: :stop, name: :stop, data: :stop, serializer: ApiWeb.StopView},
      trip: %HasOne{type: :trip, name: :trip, data: :trip, serializer: ApiWeb.TripView},
      route: %HasOne{type: :route, name: :route, data: :route, serializer: ApiWeb.RouteView},
      prediction: %HasOne{
        type: :prediction,
        name: :prediction,
        data: :prediction,
        serializer: ApiWeb.PredictionView,
        identifiers: :when_included,
        include: false
      }
    }
  end

  attributes([
    :arrival_time,
    :departure_time,
    :stop_sequence,
    :pickup_type,
    :drop_off_type,
    :timepoint,
    :direction_id
  ])

  def attributes(schedule, conn) do
    opts = Map.get(conn.assigns, :opts, [])

    fields =
      case Keyword.get(opts, :fields) do
        %{"schedule" => fields} ->
          fields

        _ ->
          Map.keys(inlined_attributes_map(schedule, conn))
      end

    base =
      schedule
      |> Map.put(:timepoint, schedule.timepoint?)
      |> Map.take(fields)

    base =
      case base do
        %{arrival_time: time} ->
          Map.put(base, :arrival_time, format_time(time, conn))

        _ ->
          base
      end

    case base do
      %{departure_time: time} ->
        Map.put(base, :departure_time, format_time(time, conn))

      _ ->
        base
    end
  end

  def id(%{trip_id: trip_id, stop_id: stop_id, stop_sequence: stop_sequence}, _conn) do
    "schedule-" <> trip_id <> "-" <> stop_id <> "-" <> Integer.to_string(stop_sequence)
  end

  def preload(schedules, %{assigns: %{date: date}} = conn, include_opts)
      when is_list(schedules) do
    schedules = super(schedules, conn, include_opts)

    if include_opts != nil and Keyword.has_key?(include_opts, :prediction) do
      predictions = State.Prediction.prediction_for_many(schedules, date)

      for s <- schedules do
        p = Map.get(predictions, {s.trip_id, s.stop_sequence})
        Map.put(s, :prediction, p)
      end
    else
      schedules
    end
  end

  def preload(schedules, conn, include_opts), do: super(schedules, conn, include_opts)

  def prediction(%{prediction: prediction}, _conn), do: prediction

  def prediction(schedule, %{assigns: %{date: date}} = conn) do
    Deadline.check!(conn)
    State.Prediction.prediction_for(schedule, date)
  end

  defp format_time(nil, _) do
    nil
  end

  defp format_time(seconds, conn) do
    conn.assigns
    |> case do
      %{date_seconds: date_seconds} -> date_seconds
      %{date: date} -> date
    end
    |> DateHelpers.add_seconds_to_date(seconds)
    |> DateTime.to_iso8601()
  end
end
