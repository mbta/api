defmodule ApiWeb.StopControllerTest do
  use ApiWeb.ConnCase
  alias Model.{Facility, Schedule, Stop, Trip}

  setup %{conn: conn} do
    State.Stop.new_state([])
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all entries", %{conn: conn} do
      conn = get(conn, stop_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, stop_path(conn, :index))

      assert validate_resp_schema(response, schema, "Stops")
    end

    test "can sort by distance to location", %{conn: base_conn} do
      stop1 = %Stop{id: "1", latitude: 1, longitude: 1}
      stop2 = %Stop{id: "3", latitude: 1, longitude: 3}
      stop3 = %Stop{id: "2", latitude: 1, longitude: 2}
      State.Stop.new_state([stop1, stop2, stop3])

      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "latitude" => "0",
          "longitude" => "0",
          "radius" => "10",
          "sort" => "distance"
        })

      assert [
               %{"attributes" => %{"longitude" => 1}},
               %{"attributes" => %{"longitude" => 2}},
               %{"attributes" => %{"longitude" => 3}}
             ] = json_response(conn, 200)["data"]

      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "latitude" => "0",
          "longitude" => "0",
          "radius" => "10",
          "sort" => "-distance"
        })

      assert [
               %{"attributes" => %{"longitude" => 3}},
               %{"attributes" => %{"longitude" => 2}},
               %{"attributes" => %{"longitude" => 1}}
             ] = json_response(conn, 200)["data"]
    end

    test "can sort by distance to location with filter[latitude] or just latitude", %{
      conn: base_conn
    } do
      stop1 = %Stop{id: "1", latitude: 1, longitude: 1}
      stop2 = %Stop{id: "3", latitude: 1, longitude: 3}
      stop3 = %Stop{id: "2", latitude: 1, longitude: 2}
      State.Stop.new_state([stop1, stop2, stop3])

      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "filter" => %{"latitude" => "0", "longitude" => "0"},
          "radius" => "10",
          "sort" => "distance"
        })

      assert [
               %{"attributes" => %{"longitude" => 1}},
               %{"attributes" => %{"longitude" => 2}},
               %{"attributes" => %{"longitude" => 3}}
             ] = json_response(conn, 200)["data"]

      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "latitude" => "0",
          "filter" => %{"longitude" => "0"},
          "radius" => "10",
          "sort" => "distance"
        })

      assert [
               %{"attributes" => %{"longitude" => 1}},
               %{"attributes" => %{"longitude" => 2}},
               %{"attributes" => %{"longitude" => 3}}
             ] = json_response(conn, 200)["data"]
    end

    test "returns 400 if sort=distance is specified and latitude or longitude is missing", %{
      conn: base_conn
    } do
      stop = %Stop{id: "1", latitude: 1, longitude: 1}
      State.Stop.new_state([stop])

      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "latitude" => "0",
          "radius" => "10",
          "sort" => "distance"
        })

      assert conn.status == 400
    end

    test "returns 400 if sort=distance is specified and latitude or longitude is invalid", %{
      conn: base_conn
    } do
      stop = %Stop{id: "1", latitude: 1, longitude: 1}
      State.Stop.new_state([stop])

      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "filter" => %{"latitude" => "{1}", "longitude" => "{0}"},
          "sort" => "distance"
        })

      assert conn.status == 400
    end

    test "can search by location", %{conn: base_conn} do
      stop = %Stop{id: "1", latitude: 1, longitude: 2}
      State.Stop.new_state([stop])

      conn =
        get(base_conn, stop_path(base_conn, :index), %{"latitude" => "1", "longitude" => "2"})

      assert List.first(json_response(conn, 200)["data"])["id"] == "1"
      # too far for default
      conn =
        get(base_conn, stop_path(base_conn, :index), %{"latitude" => "2", "longitude" => "2"})

      assert json_response(conn, 200)["data"] == []
      # set the radius
      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "latitude" => "2",
          "longitude" => "2",
          "radius" => "1"
        })

      assert List.first(json_response(conn, 200)["data"])["id"] == "1"
    end

    test "can search by ids", %{conn: conn} do
      stops =
        for id <- ~w(one two three) do
          %Stop{id: id}
        end

      State.Stop.new_state(stops)

      conn = get(conn, stop_path(conn, :index), %{"id" => "one,three"})

      ids =
        for data <- json_response(conn, 200)["data"] do
          data["id"]
        end

      assert Enum.sort(ids) == ~w(one three)
    end

    test "can search by route and route type", %{conn: base_conn} do
      # set up the data for StopsOnRoute
      set_up_stops_on_route()

      conn = get(base_conn, stop_path(base_conn, :index), %{"route" => "route"})
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["1"]

      conn = get(base_conn, stop_path(base_conn, :index), %{"route" => "route,other"})
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["2", "1"]

      conn = get(base_conn, stop_path(base_conn, :index), %{"route" => "other route"})
      assert json_response(conn, 200)["data"] == []

      # route type query
      conn = get(base_conn, stop_path(base_conn, :index), %{"route_type" => "2,3"})
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["1"]

      conn = get(base_conn, stop_path(base_conn, :index), %{"route_type" => "3"})
      assert json_response(conn, 200)["data"] == []

      # route type query combined with lat/long query
      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "route_type" => "2",
          "latitude" => "1",
          "longitude" => "2"
        })

      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["1"]

      # null intersection between route type and lat/long queries
      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "route_type" => "4",
          "latitude" => "1",
          "longitude" => "2"
        })

      assert json_response(conn, 200)["data"] == []
    end

    test "keeps stops in route order", %{conn: conn} do
      for _ <- 0..10 do
        stop = %Stop{id: random_id()}
        stop2 = %Stop{id: random_id()}
        State.Stop.new_state([stop, stop2])
        State.Route.new_state([%Model.Route{id: "route"}])
        State.Trip.new_state([%Model.Trip{id: "trip", route_id: "route"}])

        State.Schedule.new_state([
          %Model.Schedule{trip_id: "trip", stop_id: stop.id, stop_sequence: 1},
          %Model.Schedule{trip_id: "trip", stop_id: stop2.id, stop_sequence: 2}
        ])

        State.StopsOnRoute.update!()

        conn = get(conn, stop_path(conn, :index), %{"filter" => %{"route" => "route"}})
        assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == [stop.id, stop2.id]
      end
    end

    test "can include a route we're filtering on", %{conn: conn} do
      set_up_stops_on_route()

      response =
        conn
        |> get(
          stop_path(conn, :index, %{"filter" => %{"route" => "route"}, "include" => "route"})
        )
        |> json_response(200)

      assert %{
               "type" => "route",
               "id" => "route"
             } = List.first(response["included"])
    end

    test "can filter on route and direction_id", %{conn: base_conn} do
      set_up_stops_on_route()

      params = %{"filter" => %{"route" => "route,other", "direction_id" => "1"}}
      conn = get(base_conn, stop_path(base_conn, :index, params))
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["1"]

      params = put_in(params, ["filter", "direction_id"], "0")
      conn = get(base_conn, stop_path(base_conn, :index, params))
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["2"]
    end

    test "can filter routes by date", %{conn: base_conn} do
      today = Parse.Time.service_date()
      future = %{today | year: today.year + 1}
      bad_date = %{today | year: today.year - 1}
      stop = %Stop{id: "1"}

      service = %Model.Service{
        id: "service",
        start_date: today,
        end_date: today,
        added_dates: [today]
      }

      route = %Model.Route{id: "route", type: 2}
      trip = %Model.Trip{id: "trip", route_id: "route", service_id: "service"}
      schedule = %Model.Schedule{trip_id: "trip", stop_id: "1"}
      feed = %Model.Feed{start_date: bad_date, end_date: future}
      State.Service.new_state([service])
      State.Trip.reset_gather()
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      State.StopsOnRoute.update!()
      State.Feed.new_state(feed)

      today_iso = Date.to_iso8601(today)
      bad_date_iso = Date.to_iso8601(bad_date)

      params = %{"filter" => %{"route" => "route", "date" => today_iso}}
      conn = get(base_conn, stop_path(base_conn, :index, params))
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["1"]

      params = put_in(params, ["filter", "date"], bad_date_iso)
      conn = get(base_conn, stop_path(base_conn, :index, params))
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == []
    end

    test "can filter routes by service", %{conn: base_conn} do
      today = Parse.Time.service_date()
      stop = %Stop{id: "1"}
      service = %Model.Service{id: "service", start_date: today, end_date: today}
      route = %Model.Route{id: "route", type: 2}
      trip = %Model.Trip{id: "trip", route_id: "route", service_id: "service"}
      schedule = %Model.Schedule{trip_id: "trip", stop_id: "1"}
      State.Service.new_state([service])
      State.Trip.reset_gather()
      State.Stop.new_state([stop])
      State.Route.new_state([route])
      State.Trip.new_state([trip])
      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      State.StopsOnRoute.update!()

      params = %{"filter" => %{"route" => "route", "service" => "service"}}
      conn = get(base_conn, stop_path(base_conn, :index, params))
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["1"]

      params = put_in(params, ["filter", "service"], "bad_service")
      conn = get(base_conn, stop_path(base_conn, :index, params))
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == []
    end

    test "can filter by location_type", %{conn: base_conn} do
      stop = %Stop{id: 1, location_type: 0}
      State.Stop.new_state([stop])

      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "location_type" => "1,2"
        })

      assert json_response(conn, 200)["data"] == []

      conn =
        get(base_conn, stop_path(base_conn, :index), %{
          "location_type" => "0"
        })

      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["1"]
    end

    test "can be paginated and sorted", %{conn: base_conn} do
      set_up_stops_on_route()

      opts = %{"page" => %{"offset" => 1, "limit" => 1}}

      conn = get(base_conn, stop_path(base_conn, :index, Map.merge(opts, %{"sort" => "id"})))
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["2"]

      conn = get(base_conn, stop_path(base_conn, :index, Map.merge(opts, %{"sort" => "-id"})))
      assert Enum.map(json_response(conn, 200)["data"], & &1["id"]) == ["1"]
    end

    test "can include facilities", %{conn: conn} do
      facility = %Facility{id: "6", stop_id: "stop"}
      State.Facility.new_state([facility])
      stop = %Stop{id: "stop"}
      State.Stop.new_state([stop])
      conn = get(conn, stop_path(conn, :index), %{include: "facilities"})
      response = json_response(conn, 200)
      [stop] = response["data"]

      assert [%{"type" => "facility", "id" => "6"}] = stop["relationships"]["facilities"]["data"]

      assert [%{"type" => "facility", "id" => "6"}] = response["included"]
    end

    test "can filter by ID with legacy stop ID translation", %{conn: conn} do
      State.Stop.new_state([%Stop{id: "place-nubn"}, %Stop{id: "other"}])

      response =
        conn
        |> assign(:api_version, "2020-05-01")
        |> get(stop_path(conn, :index), %{"id" => "place-dudly,other"})
        |> json_response(200)

      assert Enum.map(response["data"], & &1["id"]) == ~w(place-nubn other)
    end
  end

  describe "show" do
    test "shows chosen resource", %{conn: conn} do
      stop = %Stop{id: "1"}
      State.Stop.new_state([stop])
      conn = get(conn, stop_path(conn, :show, stop))
      assert json_response(conn, 200)["data"]["id"] == stop.id
    end

    test "does not allow filtering", %{conn: conn} do
      stop = %Stop{id: "1"}
      State.Stop.new_state([stop])
      conn = get(conn, stop_path(conn, :show, stop.id, %{"filter[route]" => "1"}))
      assert json_response(conn, 400)
    end

    test "does not crash when given weird input", %{conn: conn} do
      conn = get(conn, stop_path(conn, :show, "%"))
      assert json_response(conn, 404)
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      stop = %Stop{
        id: "1",
        latitude: 42.3605,
        longitude: -71.0596,
        name: "Boston",
        wheelchair_boarding: 1,
        parent_station: "2"
      }

      parent_station = %Stop{id: "2"}
      State.Stop.new_state([stop, parent_station])
      response = get(conn, stop_path(conn, :show, "1"))

      assert validate_resp_schema(response, schema, "Stop")
    end

    test "can include a parent stop", %{conn: conn} do
      parent = %Stop{id: "1"}
      child = %Stop{id: "2", parent_station: "1"}
      State.Stop.new_state([parent, child])
      conn = get(conn, stop_path(conn, :show, child), %{include: "parent_station"})
      response = json_response(conn, 200)
      assert response["data"]["relationships"]["parent_station"]["data"]["id"] == "1"
      [included] = response["included"]
      assert included["id"] == "1"
    end

    test "can include child stops", %{conn: conn} do
      parent = %Stop{id: "1"}
      child = %Stop{id: "2", parent_station: "1"}
      State.Stop.new_state([parent, child])

      conn = get(conn, stop_path(conn, :show, parent))
      response = json_response(conn, 200)

      # no data included
      refute response["data"]["relationships"]["child_stops"]["data"]

      conn = get(conn, stop_path(conn, :show, parent), %{include: "child_stops"})
      response = json_response(conn, 200)

      assert response["data"]["relationships"]["child_stops"]["data"] == [
               %{"type" => "stop", "id" => "2"}
             ]

      [included] = response["included"]
      assert included["id"] == "2"
    end

    test "can include connecting stops", %{conn: conn} do
      State.Stop.new_state([
        %Stop{id: "parent", location_type: 1, latitude: 42, longitude: -71},
        %Stop{
          id: "child",
          location_type: 0,
          parent_station: "parent",
          latitude: 42,
          longitude: -71
        },
        %Stop{
          id: "entrance",
          location_type: 2,
          parent_station: "parent",
          latitude: 42.002,
          longitude: -71
        },
        %Stop{id: "close", location_type: 0, latitude: 42.0021, longitude: -71},
        %Stop{id: "far", location_type: 0, latitude: 42.005, longitude: -71}
      ])

      State.Trip.new_state([
        %Trip{id: "trip1", route_pattern_id: "pattern1", direction_id: 0},
        %Trip{id: "trip2", route_pattern_id: "pattern2", direction_id: 0},
        %Trip{id: "trip3", route_pattern_id: "pattern2", direction_id: 0}
      ])

      State.Schedule.new_state([
        %Schedule{trip_id: "trip1", stop_id: "child"},
        %Schedule{trip_id: "trip2", stop_id: "close"},
        %Schedule{trip_id: "trip3", stop_id: "far"}
      ])

      State.RoutesPatternsAtStop.update!()
      State.ConnectingStops.update!()

      # should not be included by default
      conn = get(conn, stop_path(conn, :show, "parent"))
      response = json_response(conn, 200)
      refute response["data"]["relationships"]["connecting_stops"]["data"]

      # should be included when requested
      conn = get(conn, stop_path(conn, :show, "parent"), %{include: "connecting_stops"})
      response = json_response(conn, 200)
      connecting_stops = response["data"]["relationships"]["connecting_stops"]["data"]
      assert connecting_stops == [%{"type" => "stop", "id" => "close"}]
      assert [%{"id" => "close"}] = response["included"]

      # should be included using the deprecated alias `recommended_transfers`
      conn = get(conn, stop_path(conn, :show, "parent"), %{include: "recommended_transfers"})
      response = json_response(conn, 200)
      connecting_stops = response["data"]["relationships"]["recommended_transfers"]["data"]
      assert connecting_stops == [%{"type" => "stop", "id" => "close"}]
    end

    test "can include facilities", %{conn: conn} do
      facility = %Facility{id: "6", stop_id: "stop"}
      State.Facility.new_state([facility])
      stop = %Stop{id: "stop"}
      State.Stop.new_state([stop])
      conn = get(conn, stop_path(conn, :show, stop), %{include: "facilities"})
      response = json_response(conn, 200)

      assert [%{"type" => "facility", "id" => "6"}] =
               response["data"]["relationships"]["facilities"]["data"]

      assert [%{"type" => "facility", "id" => "6"}] = response["included"]
    end

    test "can filter fields", %{conn: conn} do
      stop = %Stop{id: "1"}
      State.Stop.new_state([stop])
      conn = get(conn, stop_path(conn, :show, stop, %{"fields[stop]" => ""}))
      assert json_response(conn, 200)["data"]["attributes"] == %{}
    end

    test "has zone relationship in response", %{conn: conn} do
      stop1 = %Stop{id: "1", zone_id: "CR-zone-6"}
      stop2 = %Stop{id: "2", zone_id: nil}
      State.Stop.new_state([stop1, stop2])

      conn = get(conn, stop_path(conn, :show, stop1))
      response = json_response(conn, 200)

      assert response["data"]["relationships"]["zone"]["data"] == %{
               "id" => "CR-zone-6",
               "type" => "zone"
             }

      conn = get(conn, stop_path(conn, :show, stop2))
      response = json_response(conn, 200)
      refute response["data"]["relationships"]["zone"]["data"]
    end

    test "cannot include zone", %{conn: conn} do
      stop = %Stop{id: "1", zone_id: "CR-zone-6"}
      State.Stop.new_state([stop])

      response = get(conn, stop_path(conn, :show, stop, %{"include" => "zone"}))
      assert json_response(response, 400)
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: swagger_shema
    } do
      conn = get(conn, stop_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, swagger_shema, "NotFound")
    end

    test "returns CORS headers", %{conn: conn} do
      origin = "https://cors.origin"

      conn =
        conn
        |> put_req_header("origin", origin)
        |> get(stop_path(conn, :index))

      assert json_response(conn, 200)
      refute get_resp_header(conn, "access-control-allow-origin") == []
    end

    test "translates stop IDs that were renamed", %{conn: conn} do
      State.Stop.new_state([%Stop{id: "place-nubn"}])

      response =
        conn
        |> assign(:api_version, "2020-05-01")
        |> get(stop_path(conn, :show, "place-dudly"))
        |> json_response(200)

      assert response["data"]["id"] == "place-nubn"

      response =
        conn
        |> assign(:api_version, "2021-01-09")
        |> get(stop_path(conn, :show, "place-dudly"))
        |> json_response(404)

      assert response["errors"]

      # ensure this also works *before* the transition has occurred

      State.Stop.new_state([%Stop{id: "place-dudly"}])

      response =
        conn
        |> assign(:api_version, "2020-05-01")
        |> get(stop_path(conn, :show, "place-dudly"))
        |> json_response(200)

      assert response["data"]["id"] == "place-dudly"

      response =
        conn
        |> assign(:api_version, "2021-01-09")
        |> get(stop_path(conn, :show, "place-dudly"))
        |> json_response(200)

      assert response["data"]["id"] == "place-dudly"
    end

    test "doesn't translate stop IDs that weren't renamed", %{conn: conn} do
      State.Stop.new_state([%Stop{id: "Alewife-01"}, %Stop{id: "Alewife-02"}])

      response =
        conn
        |> assign(:api_version, "2018-07-23")
        |> get(stop_path(conn, :show, "70061"))
        |> json_response(404)

      assert response["errors"]
    end
  end

  test "state_module/0" do
    assert State.Stop.Cache == ApiWeb.StopController.state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /stops" do
      assert %{"/stops" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               ApiWeb.StopController.swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /stops/{id}" do
      assert %{
               "/stops/{id}" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{},
                     "404" => %{}
                   }
                 }
               }
             } = ApiWeb.StopController.swagger_path_show(%{})
    end
  end

  defp random_id do
    System.unique_integer() |> Integer.to_string()
  end

  defp set_up_stops_on_route do
    stop = %Stop{id: "1", latitude: 1, longitude: 2}
    stop2 = %Stop{id: "2"}
    State.Stop.new_state([stop, stop2])

    State.Route.new_state([%Model.Route{id: "route", type: 2}, %Model.Route{id: "other", type: 4}])

    State.Trip.new_state([
      %Model.Trip{id: "trip", route_id: "route", direction_id: 1},
      %Model.Trip{id: "other", route_id: "other", direction_id: 0}
    ])

    State.Schedule.new_state([
      %Model.Schedule{trip_id: "trip", stop_id: "1", route_id: "route"},
      %Model.Schedule{trip_id: "other", stop_id: "2", route_id: "other"}
    ])

    State.RoutesPatternsAtStop.update!()
    State.StopsOnRoute.update!()
  end
end
