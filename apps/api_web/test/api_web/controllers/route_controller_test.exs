defmodule ApiWeb.RouteControllerTest do
  use ApiWeb.ConnCase

  @route %Model.Route{
    id: "1",
    agency_id: "1",
    type: 1,
    sort_order: 1,
    description: "First Route",
    fare_class: "Ferry",
    short_name: "First",
    long_name: "The First",
    color: "FFFFFF",
    text_color: "000000",
    line_id: "line-First",
    direction_names: ["Outbound", "Inbound"],
    direction_destinations: ["One", "Another"]
  }
  @route2 %Model.Route{
    id: "2",
    agency_id: "1",
    type: 1,
    sort_order: 2,
    description: "Second Route",
    fare_class: "Ferry",
    short_name: "Second",
    long_name: "The Second",
    color: "FFFFFF",
    text_color: "000000",
    line_id: "line-First",
    direction_names: ["Outbound", "Inbound"],
    direction_destinations: ["One", "Another"]
  }
  @route3 %Model.Route{
    id: "3",
    agency_id: "1",
    type: 2,
    sort_order: 3,
    description: "Third Route",
    fare_class: "Ferry",
    short_name: "Third",
    long_name: "The Third",
    color: "FFFFFF",
    text_color: "000000",
    direction_names: ["Outbound", "Inbound"],
    direction_destinations: ["One", "Another"]
  }
  @line1 %Model.Line{
    id: "line-First",
    short_name: "First Line"
  }

  setup %{conn: conn} do
    State.Route.new_state([@route, @route2, @route3])
    State.Line.new_state([@line1])
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index_data/2" do
    test "lists all entries on index by sort order", %{conn: conn} do
      conn = get(conn, route_path(conn, :index))
      response = json_response(conn, 200)

      assert [
               %{"type" => "route", "id" => "1"},
               %{"type" => "route", "id" => "2"},
               %{"type" => "route", "id" => "3"}
             ] = response["data"]
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, route_path(conn, :index))

      assert validate_resp_schema(response, schema, "Routes")
    end

    test "can filter by multiple ids", %{conn: conn} do
      assert ApiWeb.RouteController.index_data(conn, %{"filter" => %{"id" => "1,2"}}) == [
               @route,
               @route2
             ]
    end

    test "can filter by type", %{conn: conn} do
      assert ApiWeb.RouteController.index_data(conn, %{"filter" => %{"type" => "1"}}) == [
               @route,
               @route2
             ]

      assert ApiWeb.RouteController.index_data(conn, %{"type" => "not_a_number"}) == [
               @route,
               @route2,
               @route3
             ]

      assert ApiWeb.RouteController.index_data(conn, %{"type" => "2"}) == [@route3]
    end

    test "can filter by multiple types", %{conn: conn} do
      assert ApiWeb.RouteController.index_data(conn, %{"filter" => %{"type" => "1,2"}}) == [
               @route,
               @route2,
               @route3
             ]
    end

    test "can filter by stop", %{conn: conn} do
      stop = %Model.Stop{id: "1", latitude: 1, longitude: 2}
      stop2 = %Model.Stop{id: "2"}
      State.Stop.new_state([stop, stop2])
      State.Trip.new_state([%Model.Trip{id: "trip", route_id: "1", route_pattern_id: "rpi"}])

      State.Schedule.new_state([
        %Model.Schedule{trip_id: "trip", stop_id: "1"},
        %Model.Schedule{trip_id: "other", stop_id: "2"}
      ])

      State.RoutesAtStop.update!()

      assert ApiWeb.RouteController.index_data(conn, %{"stop" => "1"}) == [@route]
      assert ApiWeb.RouteController.index_data(conn, %{"stop" => "2"}) == []

      # can be included
      conn = get(conn, route_path(conn, :index, stop: "1", include: "stop"))
      response = json_response(conn, 200)

      assert %{
               "type" => "stop",
               "id" => "1"
             } = List.first(response["included"])
    end

    test "can filter by stop and direction_id", %{conn: conn} do
      trip1 = %Model.Trip{id: "trip1", route_id: "1", direction_id: 0, route_pattern_id: "rpi"}
      trip2 = %Model.Trip{id: "trip2", route_id: "2", direction_id: 1, route_pattern_id: "rpi"}
      State.Trip.new_state([trip1, trip2])
      stop1 = %Model.Stop{id: "1"}
      stop2 = %Model.Stop{id: "2"}
      State.Stop.new_state([stop1, stop2])
      schedule1 = %Model.Schedule{trip_id: "trip1", stop_id: "1"}
      schedule2 = %Model.Schedule{trip_id: "trip2", stop_id: "2"}
      State.Schedule.new_state([schedule1, schedule2])
      State.RoutesAtStop.update!()

      params = %{"filter" => %{"stop" => "1,2", "direction_id" => "0"}}
      assert ApiWeb.RouteController.index_data(conn, params) == [@route]
      params = put_in(params, ["filter", "direction_id"], "1")
      assert ApiWeb.RouteController.index_data(conn, params) == [@route2]
    end

    test "can filter by stop and type", %{conn: conn} do
      trip1 = %Model.Trip{id: "trip1", route_id: "1", direction_id: 0, route_pattern_id: "rpi"}
      trip2 = %Model.Trip{id: "trip2", route_id: "3", direction_id: 1, route_pattern_id: "rpi"}
      State.Trip.new_state([trip1, trip2])
      stop1 = %Model.Stop{id: "1"}
      stop2 = %Model.Stop{id: "2"}
      State.Stop.new_state([stop1, stop2])
      schedule1 = %Model.Schedule{trip_id: "trip1", stop_id: "1"}
      schedule2 = %Model.Schedule{trip_id: "trip2", stop_id: "2"}
      State.Schedule.new_state([schedule1, schedule2])
      State.RoutesAtStop.update!()

      params = %{"filter" => %{"stop" => "1,2", "type" => "1"}}
      assert ApiWeb.RouteController.index_data(conn, params) == [@route]
      params = put_in(params, ["filter", "type"], "2")
      assert ApiWeb.RouteController.index_data(conn, params) == [@route3]
    end

    test "can filter by stop and date", %{conn: base_conn} do
      # need to use a real date: otherwise State.Service throws away services
      # that are only valid in the past
      today = Parse.Time.service_date()
      bad_date = ~D[2017-01-01]
      stop = %Model.Stop{id: "1"}

      service = %Model.Service{
        id: "service",
        start_date: today,
        end_date: today,
        added_dates: [today]
      }

      route = %Model.Route{id: "route"}

      trip = %Model.Trip{
        id: "trip",
        route_id: route.id,
        service_id: service.id,
        route_pattern_id: "rpi"
      }

      schedule = %Model.Schedule{trip_id: trip.id, stop_id: stop.id}
      State.Service.new_state([service])
      State.Trip.reset_gather()
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesAtStop.update!()

      today_iso = Date.to_iso8601(today)
      bad_date_iso = Date.to_iso8601(bad_date)

      params = %{"filter" => %{"stop" => "1", "date" => today_iso}}
      data = ApiWeb.RouteController.index_data(base_conn, params)
      assert [route] == data

      params = put_in(params["filter"]["date"], bad_date_iso)
      data = ApiWeb.RouteController.index_data(base_conn, params)
      assert [] == data
    end

    test "pagination", %{conn: conn} do
      params = %{"page" => %{"offset" => 2, "limit" => 1}}
      conn = get(conn, route_path(conn, :index, params))

      response = json_response(conn, 200)
      assert [%{"type" => "route", "id" => "3"}] = response["data"]
    end

    test "pagination can override default ordering", %{conn: conn} do
      params = %{"page" => %{"offset" => 2, "limit" => 1}, "sort" => "-sort_order"}
      conn = get(conn, route_path(conn, :index, params))

      response = json_response(conn, 200)
      assert [%{"type" => "route", "id" => "1"}] = response["data"]
    end

    test "by default, filters out hidden routes", %{conn: conn} do
      hidden = %{@route | id: "Shuttle-hidden", listed_route: false}

      State.Route.new_state([
        @route,
        hidden
      ])

      assert ApiWeb.RouteController.index_data(conn, %{}) == [@route]
    end

    test "if all routes were hidden, show them anyways", %{conn: conn} do
      hidden = %{@route | id: "Shuttle-hidden", listed_route: false}

      State.Route.new_state([
        @route,
        hidden
      ])

      assert ApiWeb.RouteController.index_data(conn, %{"id" => hidden.id}) == [hidden]
    end
  end

  describe "show" do
    test "shows chosen resource", %{conn: conn} do
      conn = get(conn, route_path(conn, :show, @route))

      assert json_response(conn, 200)["data"] == %{
               "type" => "route",
               "id" => @route.id,
               "attributes" => %{
                 "description" => "First Route",
                 "fare_class" => "Ferry",
                 "long_name" => "The First",
                 "short_name" => "First",
                 "type" => 1,
                 "direction_names" => ["Outbound", "Inbound"],
                 "direction_destinations" => ["One", "Another"],
                 "sort_order" => 1,
                 "color" => "FFFFFF",
                 "text_color" => "000000"
               },
               "links" => %{
                 "self" => "/routes/#{@route.id}"
               },
               "relationships" => %{
                 "line" => %{
                   "data" => %{
                     "id" => @line1.id,
                     "type" => "line"
                   }
                 }
               }
             }
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, route_path(conn, :show, @route))

      assert validate_resp_schema(response, schema, "Route")
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: swagger_shema
    } do
      conn = get(conn, route_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, swagger_shema, "NotFound")
    end
  end

  test "state_module/0" do
    assert State.Route == ApiWeb.RouteController.state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /routes" do
      assert %{"/routes" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               ApiWeb.RouteController.swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /routes/{id}" do
      assert %{
               "/routes/{id}" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{},
                     "404" => %{}
                   }
                 }
               }
             } = ApiWeb.RouteController.swagger_path_show(%{})
    end
  end
end
