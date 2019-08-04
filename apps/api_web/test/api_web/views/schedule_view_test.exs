defmodule ApiWeb.ScheduleViewTest do
  use ApiWeb.ConnCase
  use Timex

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  alias Model.{Schedule, Service}

  @today Date.utc_today()
  @service %Service{
    id: "service",
    start_date: @today,
    end_date: @today,
    added_dates: [@today]
  }
  @schedule %Schedule{
    trip_id: "trip",
    route_id: "route",
    stop_id: "stop",
    direction_id: 1,
    arrival_time: 100,
    departure_time: 90_000,
    stop_sequence: 1,
    pickup_type: 2,
    drop_off_type: 3,
    timepoint?: true,
    service_id: "service"
  }

  setup do
    State.Service.new_state([@service])
    State.ServiceByDate.update!()
    :ok
  end

  test "renders the dates properly", %{conn: conn} do
    conn = assign(conn, :date, ~D[2016-06-07])

    rendered = render(ApiWeb.ScheduleView, "index.json-api", data: @schedule, conn: conn)

    assert rendered["data"]["attributes"] == %{
             "arrival_time" => "2016-06-07T00:01:40-04:00",
             "departure_time" => "2016-06-08T01:00:00-04:00",
             "stop_sequence" => 1,
             "pickup_type" => 2,
             "drop_off_type" => 3,
             "timepoint" => true,
             "direction_id" => 1
           }
  end

  test "handles times on DST", %{conn: conn} do
    conn = assign(conn, :date, ~D[2016-11-05])
    rendered = render(ApiWeb.ScheduleView, "index.json-api", data: @schedule, conn: conn)
    assert rendered["data"]["attributes"]["arrival_time"] == "2016-11-05T00:01:40-04:00"
    assert rendered["data"]["attributes"]["departure_time"] == "2016-11-06T01:00:00-04:00"
  end

  test "does not include values which aren't requested", %{conn: conn} do
    conn =
      conn
      |> assign(:date, ~D[2016-11-05])
      |> assign(:opts, fields: %{"schedule" => []})

    rendered = render(ApiWeb.ScheduleView, "index.json-api", data: @schedule, conn: conn)
    assert rendered["data"]["attributes"] == %{}
  end

  describe "has_one prediction" do
    test "returns a related prediction", %{conn: conn} do
      today = Timex.to_datetime(@today, "America/New_York")

      associated_prediction = %Model.Prediction{
        route_id: "route",
        trip_id: "trip",
        stop_id: "stop",
        stop_sequence: 1,
        direction_id: 1,
        arrival_time: Timex.add(today, Duration.from_seconds(45_000)),
        departure_time: Timex.add(today, Duration.from_seconds(45_010))
      }

      other_prediction = %Model.Prediction{
        route_id: "other_route",
        trip_id: "other_trip",
        stop_id: "other_stop",
        stop_sequence: 0,
        direction_id: 1,
        arrival_time: Timex.add(today, Duration.from_seconds(45_000)),
        departure_time: Timex.add(today, Duration.from_seconds(45_010))
      }

      State.Prediction.new_state([associated_prediction, other_prediction])
      conn = assign(conn, :date, @today)

      prediction_id =
        ApiWeb.ScheduleView
        |> render("index.json-api", data: @schedule, conn: conn, opts: [include: "prediction"])
        |> get_in(["data", "relationships", "prediction", "data", "id"])

      assert prediction_id == "prediction-trip-stop-1"
    end

    test "does not return a prediction if not explicitly requested", %{conn: conn} do
      today = Timex.to_datetime(~D[2016-06-07], "America/New_York")

      associated_prediction = %Model.Prediction{
        route_id: "route",
        trip_id: "trip",
        stop_id: "stop",
        stop_sequence: 1,
        direction_id: 1,
        arrival_time: Timex.add(today, Duration.from_seconds(45_000)),
        departure_time: Timex.add(today, Duration.from_seconds(45_010))
      }

      other_prediction = %Model.Prediction{
        route_id: "other_route",
        trip_id: "other_trip",
        stop_id: "other_stop",
        stop_sequence: 0,
        direction_id: 1,
        arrival_time: Timex.add(today, Duration.from_seconds(45_000)),
        departure_time: Timex.add(today, Duration.from_seconds(45_010))
      }

      State.Prediction.new_state([associated_prediction, other_prediction])
      conn = assign(conn, :date, ~D[2017-06-07])

      prediction =
        ApiWeb.ScheduleView
        |> render("index.json-api", data: @schedule, conn: conn, opts: [])
        |> get_in(["data", "relationships", "prediction"])

      assert prediction == %{}
    end

    test "only returns predictions for the date of the schedule", %{conn: conn} do
      today = Timex.to_datetime(~D[2016-06-07], "America/New_York")

      associated_prediction = %Model.Prediction{
        route_id: "route",
        trip_id: "trip",
        stop_id: "stop",
        stop_sequence: 1,
        direction_id: 1,
        arrival_time: Timex.add(today, Duration.from_seconds(45_000)),
        departure_time: Timex.add(today, Duration.from_seconds(45_010))
      }

      State.Prediction.new_state([associated_prediction])
      # day after tomorrow
      conn = assign(conn, :date, ~D[2016-06-09])

      prediction =
        ApiWeb.ScheduleView
        |> render("index.json-api", data: @schedule, conn: conn, opts: [include: "prediction"])
        |> get_in(["data", "relationships", "prediction", "data"])

      refute prediction
    end
  end
end
