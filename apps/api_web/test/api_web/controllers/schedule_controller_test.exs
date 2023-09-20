defmodule ApiWeb.SchedulerControllerTest do
  use ApiWeb.ConnCase
  use Timex

  import ApiWeb.ScheduleController

  alias Parse.Time

  @route %Model.Route{id: "route"}
  @stop %Model.Stop{id: "stop"}
  @service %Model.Service{
    id: "service",
    valid_days: [],
    start_date: Time.service_date(),
    end_date: Timex.shift(Time.service_date(), days: 2),
    added_dates: [Time.service_date()],
    removed_dates: []
  }
  @trip %Model.Trip{id: "trip", route_id: "route", direction_id: 1, service_id: "service"}
  @schedule %Model.Schedule{
    route_id: "route",
    trip_id: "trip",
    stop_id: "stop",
    direction_id: 1,
    # 12:30pm
    arrival_time: 45_000,
    departure_time: 45_100,
    drop_off_type: 0,
    pickup_type: 0,
    timepoint?: false,
    service_id: "service",
    stop_sequence: 2,
    position: :first
  }

  setup do
    State.Route.new_state([@route])
    State.Stop.new_state([@stop])
    State.Trip.new_state([@trip])
    State.Service.new_state([@service])
    State.Schedule.new_state([@schedule])
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "date/2" do
    test "defaults to today", %{conn: conn} do
      expected = Parse.Time.service_date()

      actual =
        %{conn | params: %{}}
        |> date([])
        |> (fn conn -> conn.assigns[:date] end).()

      assert expected == actual
    end

    test "parses a date", %{conn: conn} do
      expected = ~D[2016-01-01]

      actual =
        %{conn | params: %{"filter" => %{"date" => "2016-01-01"}}}
        |> date([])
        |> (fn conn -> conn.assigns[:date] end).()

      assert expected == actual
    end

    test "ignores an invalid date", %{conn: conn} do
      expected = Parse.Time.service_date()

      actual =
        %{conn | params: %{"filter" => %{"date" => "invalid"}}}
        |> date([])
        |> (fn conn -> conn.assigns[:date] end).()

      assert expected == actual
    end

    test "parses a date not in the filter", %{conn: conn} do
      expected = ~D[2016-01-01]

      actual =
        %{conn | params: %{"date" => "2016-01-01"}}
        |> date([])
        |> (fn conn -> conn.assigns[:date] end).()

      assert expected == actual
    end
  end

  describe "index_data/2" do
    test "can include nested relationship", %{conn: conn} do
      conn = get(conn, "/schedules/", trip: "trip", include: "trip.route")
      response = json_response(conn, 200)
      assert response["data"] != []
      assert response["included"] != []
    end

    test "can include prediction", %{conn: conn} do
      date = Timex.to_datetime(Time.service_date(), "America/New_York")

      associated_prediction = %Model.Prediction{
        route_id: "route",
        trip_id: "trip",
        stop_id: "stop",
        stop_sequence: 2,
        direction_id: 1,
        arrival_time: Timex.add(date, Duration.from_seconds(45_000)),
        departure_time: Timex.add(date, Duration.from_seconds(45_100))
      }

      other_prediction = %Model.Prediction{
        route_id: "other_route",
        trip_id: "other_trip",
        stop_id: "other_stop",
        stop_sequence: 2,
        direction_id: 1,
        arrival_time: Timex.add(date, Duration.from_seconds(45_000)),
        departure_time: Timex.add(date, Duration.from_seconds(45_100))
      }

      State.Prediction.new_state([associated_prediction, other_prediction])

      conn =
        get(
          conn,
          schedule_path(conn, :index),
          filter: %{trip: "trip"},
          include: "prediction"
        )

      [prediction] =
        conn
        |> json_response(200)
        |> Map.get("included")

      for attr <- ["route", "stop", "trip"] do
        assert get_in(prediction, ["relationships", attr, "id"]) ==
                 Map.get(@schedule, String.to_atom(attr))
      end

      assert get_in(prediction, ["attributes", "direction_id"]) == @schedule.direction_id
      assert get_in(prediction, ["attributes", "stop_sequence"]) == @schedule.stop_sequence
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, "/schedules/", trip: "trip", include: "trip.route")

      assert validate_resp_schema(response, schema, "Schedules")
    end

    test "does not return all items by default", %{conn: conn} do
      assert index_data(conn, %{}) == {:error, :filter_required}
    end

    test "returns an error if only the route_type filter is provided", %{conn: conn} do
      assert ApiWeb.ScheduleController.index_data(conn, %{"route_type" => "0,1"}) ==
               {:error, :only_route_type}
    end

    test "can filter by stop", %{conn: conn} do
      assert index_data(conn, %{"stop" => "stop"}) == [@schedule]
      assert index_data(conn, %{"stop" => "not stop"}) == []
    end

    test "can filter by route_type", %{conn: conn} do
      schedule1 = %Model.Schedule{
        route_id: "1",
        trip_id: "trip",
        stop_id: "stop",
        direction_id: 1,
        arrival_time: 45_000,
        departure_time: 45_100,
        drop_off_type: 0,
        pickup_type: 0,
        timepoint?: false,
        service_id: "service",
        stop_sequence: 2,
        position: :first
      }

      schedule2 = %Model.Schedule{
        route_id: "2",
        trip_id: "trip",
        stop_id: "stop",
        direction_id: 1,
        arrival_time: 45_000,
        departure_time: 45_100,
        drop_off_type: 0,
        pickup_type: 0,
        timepoint?: false,
        service_id: "service",
        stop_sequence: 2,
        position: :first
      }

      route1 = %Model.Route{
        id: "1",
        type: 1,
        sort_order: 1,
        description: "First Route",
        short_name: "First",
        long_name: "First"
      }

      route2 = %Model.Route{
        id: "2",
        type: 2,
        sort_order: 1,
        description: "Second Route",
        short_name: "Second",
        long_name: "Second"
      }

      State.Route.new_state([route1, route2])
      State.Schedule.new_state([schedule1, schedule2])

      conn = get(conn, "/schedules", %{"stop" => "stop"})
      assert Enum.sort(conn.assigns.data) == [schedule1, schedule2]

      conn = get(conn, "/schedules", %{"stop" => "stop", "route_type" => "2"})
      assert conn.assigns.data == [schedule2]

      conn = get(conn, "/schedules", %{"stop" => "stop", "route_type" => "1,2"})
      assert Enum.sort(conn.assigns.data) == [schedule1, schedule2]
    end

    test "versions before 2019-02-12 include new Kenmore stops", %{conn: conn} do
      stops = [
        %Model.Stop{id: "70200"},
        # new B branch berth
        %Model.Stop{id: "71199"}
      ]

      schedules = [%{@schedule | stop_id: "71199"}]

      State.Stop.new_state(stops)
      State.Schedule.new_state(schedules)
      query = %{"stop" => "70200"}

      conn = assign(conn, :api_version, "2018-07-23")
      assert index_data(conn, query) == schedules
      assert index_data(conn, %{"stop" => "other"}) == []

      conn = assign(conn, :api_version, "2019-02-12")
      assert index_data(conn, query) == []
    end

    test "can filter by trip", %{conn: conn} do
      assert index_data(conn, %{"trip" => "trip"}) == [@schedule]
      assert index_data(conn, %{"trip" => "not trip"}) == []
    end

    test "can filter by route", %{conn: conn} do
      assert index_data(conn, %{"route" => "route"}) == [@schedule]
      assert index_data(conn, %{"route" => "not route"}) == []
    end

    test "can filter by trip and stop", %{conn: conn} do
      other_trip = %Model.Trip{@trip | id: "not trip"}
      other_stop = %Model.Stop{@stop | id: "not stop"}
      State.Trip.new_state([@trip, other_trip])
      State.Stop.new_state([@stop, other_stop])

      assert index_data(conn, %{"trip" => "trip", "stop" => "stop"}) == [@schedule]
      assert index_data(conn, %{"trip" => "not trip", "stop" => "stop"}) == []
      assert index_data(conn, %{"trip" => "trip", "stop" => "not stop"}) == []
    end

    test "can filter routes by direction_id", %{conn: conn} do
      assert index_data(conn, %{"route" => "route", "direction_id" => "1"}) == [@schedule]
      assert index_data(conn, %{"route" => "route", "direction_id" => "0"}) == []
    end

    test "can filter routes by service date", %{conn: conn} do
      date = Date.to_iso8601(Parse.Time.service_date())
      assert index_data(conn, %{"route" => "route", "date" => date}) == [@schedule]
      assert index_data(conn, %{"route" => "route", "date" => "2016-06-06"}) == []
    end

    test "defaults to filtering by today's date", %{conn: conn} do
      date = Timex.shift(Timex.today(), days: 1)
      other_service = %{@service | id: "other service", added_dates: [date]}
      other_trip = %{@trip | id: "not trip", service_id: "other service"}
      other_stop = %{@stop | id: "not stop"}

      other_schedule =
        @schedule
        |> Map.put(:trip_id, other_trip.id)
        |> Map.put(:stop_id, other_stop.id)

      State.Service.new_state([@service, other_service])
      State.Trip.new_state([@trip, other_trip])
      State.Stop.new_state([@stop, other_stop])
      State.Schedule.new_state([@schedule, other_schedule])
      actual = index_data(conn, %{"route" => "route"})
      assert actual == [@schedule]
    end

    test "filtering by an invalid route returns no schedules", %{conn: conn} do
      assert index_data(conn, %{"route" => "no route", "stop" => "stop"}) == []
    end

    test "can filter schedules for stop by service date", %{conn: conn} do
      date = Date.to_iso8601(Parse.Time.service_date())
      assert index_data(conn, %{"stop" => "stop", "date" => date}) == [@schedule]
      assert index_data(conn, %{"stop" => "stop", "date" => "2016-06-06"}) == []
    end

    test "can filter schedules for stop by direction_id", %{conn: conn} do
      assert index_data(conn, %{"stop" => "stop", "direction_id" => "1"}) == [@schedule]
      assert index_data(conn, %{"stop" => "stop", "direction_id" => "0"}) == []
    end

    test "can filter by stop sequence", %{conn: conn} do
      assert index_data(conn, %{"trip" => "trip", "stop_sequence" => "2"}) == [@schedule]
      assert index_data(conn, %{"trip" => "trip", "stop_sequence" => "3"}) == []
      assert index_data(conn, %{"trip" => "trip", "stop_sequence" => "first"}) == [@schedule]
      assert index_data(conn, %{"trip" => "trip", "stop_sequence" => "first,last"}) == [@schedule]
    end

    test "can filter by min/max time", %{conn: conn} do
      min_time = "12:29"
      max_time = "12:31"

      params = %{
        "trip" => "trip",
        "min_time" => min_time,
        "max_time" => max_time
      }

      other_schedule =
        @schedule
        |> Map.put(:arrival_time, nil)
        |> Map.put(:departure_time, @schedule.arrival_time)

      for schedule <- [@schedule, other_schedule] do
        # make sure it works with both arrival and departure times
        State.Schedule.new_state([schedule])
        assert index_data(conn, Map.take(params, ["trip", "min_time"])) == [schedule]
        assert index_data(conn, Map.take(params, ["trip", "max_time"])) == [schedule]
        assert index_data(conn, params) == [schedule]

        params = %{
          "trip" => "trip",
          "min_time" => max_time,
          "max_time" => min_time
        }

        refute index_data(conn, Map.take(params, ["trip", "min_time"])) == [schedule]
        refute index_data(conn, Map.take(params, ["trip", "max_time"])) == [schedule]
      end
    end

    test "can handle schedules which happen on the next calendar day", %{conn: conn} do
      # 1am the next day
      schedule = %{@schedule | arrival_time: 90_000}
      State.Schedule.new_state([schedule])
      params = %{"trip" => "trip"}
      assert index_data(conn, put_in(params["max_time"], "25:30")) == [schedule]
      assert index_data(conn, put_in(params["min_time"], "24:30")) == [schedule]
      assert index_data(conn, put_in(params["min_time"], "25:30")) == []
      assert index_data(conn, put_in(params["max_time"], "05:30")) == []
      assert index_data(conn, put_in(params["max_time"], "5:30")) == []
    end

    test "paginates and sorts", %{conn: conn} do
      arrival_time = fn i ->
        {:ok, arrival_time, _} = DateTime.from_iso8601("2016-11-17 15:0#{i}:00-05:00")
        arrival_time
      end

      schedules =
        for i <- 1..9 do
          %Model.Schedule{
            route_id: "route",
            trip_id: "trip",
            stop_id: "stop",
            direction_id: 1,
            arrival_time: arrival_time.(i),
            service_id: "service",
            stop_sequence: i
          }
        end

      State.Schedule.new_state(schedules)

      schedule3 = Enum.at(schedules, 2)
      schedule4 = Enum.at(schedules, 3)
      schedule6 = Enum.at(schedules, 5)
      schedule7 = Enum.at(schedules, 6)

      opts = %{"route" => "route", "page" => %{"offset" => 2, "limit" => 2}}
      {data, _} = index_data(conn, Map.merge(opts, %{"sort" => "arrival_time"}))
      assert data == [schedule3, schedule4]
      {data, _} = index_data(conn, Map.merge(opts, %{"sort" => "-arrival_time"}))
      assert data == [schedule7, schedule6]
    end

    test "can handle nil times for schedules when sorting", %{conn: conn} do
      time_fn = fn i ->
        {:ok, t, _} = DateTime.from_iso8601("2016-11-17 15:0#{i}:00-05:00")
        t
      end

      schedules =
        for i <- 1..9 do
          %Model.Schedule{
            route_id: "route",
            trip_id: "trip",
            stop_id: "stop",
            direction_id: 1,
            pickup_type: 1,
            drop_off_type: 0,
            arrival_time: time_fn.(i),
            departure_time: nil,
            service_id: "service",
            stop_sequence: i
          }
        end

      State.Schedule.new_state(schedules)

      conn = assign(conn, :api_version, "2019-04-05")

      data = index_data(conn, %{"route" => "route", "sort" => "arrival_time"})

      for i <- 0..8 do
        assert Enum.at(data, i).departure_time == Enum.at(schedules, i).arrival_time
      end

      data =
        conn |> index_data(%{"route" => "route", "sort" => "-departure_time"}) |> Enum.reverse()

      for i <- 0..8 do
        assert Enum.at(data, i).departure_time == Enum.at(schedules, i).arrival_time
      end
    end
  end

  describe "populate_extra_times" do
    test "populates dates for older API versions", %{conn: conn} do
      conn = assign(conn, :api_version, "2019-04-05")

      schedules = [
        %Model.Schedule{
          route_id: "route",
          trip_id: "trip",
          stop_id: "stop",
          direction_id: 1,
          arrival_time: nil,
          departure_time: 45_100,
          drop_off_type: 1,
          pickup_type: 0,
          service_id: "service"
        }
      ]

      s = populate_extra_times(schedules, conn)
      assert Enum.at(s, 0).arrival_time == 45_100
    end

    test "doesn't populate dates for newer API versions", %{conn: conn} do
      conn = assign(conn, :api_version, "2019-07-01")

      schedules = [
        %Model.Schedule{
          route_id: "route",
          trip_id: "trip",
          stop_id: "stop",
          direction_id: 1,
          arrival_time: 45_100,
          departure_time: nil,
          drop_off_type: 0,
          pickup_type: 1,
          service_id: "service"
        }
      ]

      s = populate_extra_times(schedules, conn)
      assert Enum.at(s, 0).departure_time == nil
    end
  end

  test "state_module/0" do
    assert State.Schedule == ApiWeb.ScheduleController.state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /schedules" do
      assert %{"/schedules" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               ApiWeb.ScheduleController.swagger_path_index(%{})
    end
  end
end
