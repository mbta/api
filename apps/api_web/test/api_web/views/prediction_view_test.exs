defmodule ApiWeb.PredictionViewTest do
  use ApiWeb.ConnCase
  use Timex

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  alias Model.Prediction

  # GMT
  @datetime Timex.to_datetime(~N[2016-06-07T00:00:00], "America/New_York")
  @prediction %Prediction{
    trip_id: "trip",
    stop_id: "North Station-02",
    route_id: "CR-Lowell",
    vehicle_id: "vehicle",
    direction_id: 0,
    arrival_time: nil,
    arrival_uncertainty: nil,
    departure_time: @datetime,
    departure_uncertainty: 60,
    schedule_relationship: :added,
    status: "All Aboard",
    stop_sequence: 5
  }
  @route %Model.Route{id: "CR-Lowell"}
  @stop %Model.Stop{id: "North Station-02", parent_station: "place-north", platform_code: "2"}
  @stops [
    @stop,
    %Model.Stop{id: "North Station", parent_station: "place-north"},
    %Model.Stop{id: "place-north", location_type: 1}
  ]
  @trips [
    %Model.Trip{
      id: "trip",
      route_id: "CR-Lowell",
      direction_id: 1,
      service_id: "service"
    },
    %Model.Trip{
      id: "trip-2",
      route_id: "CR-Lowell",
      direction_id: 1,
      service_id: "service"
    }
  ]
  @associated_schedule %Model.Schedule{
    trip_id: "trip",
    route_id: "CR-Lowell",
    stop_id: "North Station",
    direction_id: 0,
    arrival_time: nil,
    departure_time: 20_000,
    stop_sequence: 5
  }
  @other_schedule %Model.Schedule{
    trip_id: "trip-2",
    route_id: "CR-Lowell",
    stop_id: "North Station",
    direction_id: 1,
    arrival_time: 20_000,
    departure_time: nil,
    stop_sequence: 5
  }

  setup do
    State.Route.new_state([@route])
    State.Stop.new_state(@stops)
    State.Trip.new_state(@trips)
    State.Schedule.new_state([@associated_schedule, @other_schedule])
    State.RoutesPatternsAtStop.update!()
    :ok
  end

  test "render includes the commuter rail departure", %{conn: conn} do
    rendered = render(ApiWeb.PredictionView, "index.json-api", data: @prediction, conn: conn)

    assert rendered["data"]["attributes"] == %{
             "direction_id" => 0,
             "arrival_time" => nil,
             "arrival_uncertainty" => nil,
             "departure_time" => "2016-06-07T00:00:00-04:00",
             "departure_uncertainty" => 60,
             "status" => "All Aboard",
             "schedule_relationship" => "ADDED",
             "stop_sequence" => 5,
             "revenue" => "REVENUE"
           }
  end

  test "includes trip/stop/route/vehicle relationships by default", %{conn: conn} do
    rendered = render(ApiWeb.PredictionView, "index.json-api", data: @prediction, conn: conn)

    assert rendered["data"]["relationships"] ==
             %{
               "trip" => %{"data" => %{"type" => "trip", "id" => "trip"}},
               "stop" => %{"data" => %{"type" => "stop", "id" => "North Station-02"}},
               "route" => %{"data" => %{"type" => "route", "id" => "CR-Lowell"}},
               "vehicle" => %{"data" => %{"type" => "vehicle", "id" => "vehicle"}}
             }
  end

  test "version 2018-05-07 includes the track and replaces the stop", %{conn: conn} do
    conn = assign(conn, :api_version, "2018-05-07")
    rendered = render(ApiWeb.PredictionView, "index.json-api", data: @prediction, conn: conn)
    assert rendered["data"]["attributes"]["track"] == "2"
    assert rendered["data"]["relationships"]["stop"]["data"]["id"] == "North Station"
  end

  test "handles DST times", %{conn: conn} do
    # GMT
    dst_prediction = %{
      @prediction
      | departure_time: Timex.to_datetime(~N[2016-11-06T05:00:00], "America/New_York")
    }

    rendered = render(ApiWeb.PredictionView, "index.json-api", data: dst_prediction, conn: conn)
    assert rendered["data"]["attributes"]["departure_time"] == "2016-11-06T05:00:00-05:00"
  end

  describe "has_one schedule" do
    setup %{conn: conn} do
      conn =
        conn
        |> assign(:data, [@prediction])
        |> assign(:date, Parse.Time.service_date())

      {:ok, %{conn: conn}}
    end

    test "returns a related schedule", %{conn: conn} do
      conn =
        %{conn | params: %{"include" => "schedule"}}
        |> ApiWeb.ApiControllerHelpers.split_include([])

      # added trips don't have schedules by definition
      prediction = %{@prediction | schedule_relationship: nil}

      schedule_id =
        ApiWeb.PredictionView
        |> render("index.json-api", data: prediction, conn: conn)
        |> get_in(["data", "relationships", "schedule", "data", "id"])

      assert schedule_id == "schedule-trip-North Station-5"
    end

    test "does not return a schedule if not explicitly requested", %{conn: conn} do
      schedule =
        ApiWeb.PredictionView
        |> render("index.json-api", data: @prediction, conn: conn, opts: [])
        |> get_in(["data", "relationships", "schedule", "data"])

      refute schedule
    end
  end

  describe "alerts/2" do
    test "does not crash if the prediction does not have a direction ID", %{conn: conn} do
      prediction = %Model.Prediction{}
      assert ApiWeb.PredictionView.alerts(prediction, conn)
    end
  end
end
