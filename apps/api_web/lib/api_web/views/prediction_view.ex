defmodule ApiWeb.PredictionView do
  use ApiWeb.Web, :api_view
  alias ApiWeb.Plugs.Deadline

  attributes([
    :arrival_time,
    :arrival_uncertainty,
    :departure_time,
    :departure_uncertainty,
    :direction_id,
    :last_trip,
    :schedule_relationship,
    :status,
    :stop_sequence,
    :track,
    :revenue,
    :update_type
  ])

  def preload(predictions, conn, include_opts) do
    predictions = super(predictions, conn, include_opts)

    predictions =
      if include_opts != nil and Keyword.has_key?(include_opts, :schedule) do
        schedules = State.Schedule.schedule_for_many(predictions)

        for p <- predictions do
          s = Map.get(schedules, {p.trip_id, p.stop_sequence})
          Map.put(p, :schedule, s)
        end
      else
        predictions
      end

    if include_opts != nil and Keyword.has_key?(include_opts, :alerts) do
      for prediction <- predictions do
        Map.put(prediction, :alerts, alerts(prediction, conn))
      end
    else
      predictions
    end
  end

  def attributes(%Model.Prediction{} = p, conn) do
    attributes = %{
      arrival_time: format_time(p.arrival_time),
      arrival_uncertainty: p.arrival_uncertainty,
      departure_time: format_time(p.departure_time),
      departure_uncertainty: p.departure_uncertainty,
      direction_id: p.direction_id,
      last_trip: p.last_trip?,
      schedule_relationship: upcase_atom_to_string(p.schedule_relationship),
      status: p.status,
      stop_sequence: p.stop_sequence,
      revenue: revenue(p),
      update_type: upcase_atom_to_string(p.update_type)
    }

    add_legacy_attributes(attributes, p, conn.assigns.api_version)
  end

  defp add_legacy_attributes(attributes, _, version)
       when version >= "2018-07-23" do
    attributes
  end

  defp add_legacy_attributes(attributes, p, _) do
    track =
      case State.Stop.by_id(p.stop_id) do
        %{platform_code: track} when not is_nil(track) ->
          track

        _ ->
          nil
      end

    Map.put(attributes, :track, track)
  end

  def relationships(prediction, conn) do
    relationships = [
      %HasOne{
        type: :stop,
        name: :stop,
        data: stop_or_legacy_stop(prediction, conn),
        identifiers: :always,
        serializer: ApiWeb.StopView
      },
      %HasOne{
        type: :route,
        name: :route,
        data: route(prediction, conn),
        identifiers: :always,
        serializer: ApiWeb.RouteView
      },
      %HasOne{
        type: :trip,
        name: :trip,
        data: trip(prediction, conn),
        identifiers: :always,
        serializer: ApiWeb.TripView
      },
      %HasOne{
        type: :vehicle,
        name: :vehicle,
        identifiers: :always,
        data: vehicle(prediction, conn),
        serializer: ApiWeb.VehicleView
      }
    ]

    relationships =
      if split_included?("schedule", conn) do
        [
          %HasOne{
            type: :schedule,
            name: :schedule,
            data: schedule(prediction, conn),
            serializer: ApiWeb.ScheduleView
          }
          | relationships
        ]
      else
        relationships
      end

    relationships =
      if split_included?("alerts", conn) do
        [
          %HasMany{
            type: :alerts,
            name: :alerts,
            data: alerts(prediction, conn),
            serializer: ApiWeb.AlertView
          }
          | relationships
        ]
      else
        relationships
      end

    Map.new(relationships, &{&1.name, &1})
  end

  def stop_or_legacy_stop(prediction, conn) do
    stop_id =
      if conn.assigns.api_version >= "2018-07-23" do
        prediction.stop_id
      else
        Regex.replace(~r/-\d\d$/, prediction.stop_id, "")
      end

    optional_relationship("stop", stop_id, &State.Stop.by_id/1, conn)
  end

  def id(%{trip_id: trip_id, stop_id: stop_id, stop_sequence: seq}, _conn) do
    "prediction-#{trip_id}-#{stop_id}-#{seq}"
  end

  def schedule(%{schedule: schedule}, _conn), do: schedule

  def schedule(prediction, conn) do
    Deadline.check!(conn)
    optional_relationship("schedule", prediction, &State.Schedule.schedule_for/1, conn)
  end

  def alerts(%{alerts: alerts}, _conn) do
    alerts
  end

  def alerts(%Model.Prediction{} = prediction, _conn) do
    %{activities: ["ALL"]}
    |> alert_route_filter(prediction)
    |> alert_trip_filter(prediction)
    |> alert_stop_filter(prediction)
    |> alert_direction_id_filter(prediction)
    |> alert_datetime_filter(prediction)
    |> State.Alert.filter_by()
  end

  defp alert_route_filter(acc, %{route_id: route}) do
    Map.put(acc, :routes, [route])
  end

  defp alert_trip_filter(acc, %{trip_id: trip}) do
    Map.put(acc, :trips, [trip])
  end

  defp alert_stop_filter(acc, %{stop_id: stop}) do
    Map.put(acc, :stops, [stop])
  end

  defp alert_direction_id_filter(acc, %{direction_id: direction_id})
       when direction_id in [0, 1] do
    Map.put(acc, :direction_id, direction_id)
  end

  defp alert_direction_id_filter(acc, _) do
    acc
  end

  defp alert_datetime_filter(acc, %{arrival_time: arr_time, departure_time: dep_time}) do
    time = arr_time || dep_time || DateTime.utc_now()
    Map.put(acc, :datetime, time)
  end

  def revenue(%{revenue: atom}) do
    Atom.to_string(atom)
  end

  def format_time(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  def format_time(nil), do: nil

  defp upcase_atom_to_string(nil), do: nil

  defp upcase_atom_to_string(atom) do
    atom
    |> Atom.to_string()
    |> String.upcase()
  end
end
