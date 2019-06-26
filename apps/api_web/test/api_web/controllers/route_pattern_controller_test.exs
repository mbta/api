defmodule ApiWeb.RoutePatternControllerTest do
  @moduledoc false
  use ApiWeb.ConnCase

  alias Model.Route
  alias Model.RoutePattern
  alias Model.Trip

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index_data/2" do
    test "lists all entries on index by sort order", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", sort_order: "200"},
        %RoutePattern{id: "rp2", sort_order: "100"}
      ])

      conn = get(conn, route_pattern_path(conn, :index))
      response = json_response(conn, 200)

      assert [
               %{"type" => "route_pattern", "id" => "rp2"},
               %{"type" => "route_pattern", "id" => "rp1"}
             ] = response["data"]
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      route_pattern = %RoutePattern{
        id: "route pattern id",
        route_id: "route id",
        direction_id: 0,
        name: "route pattern name",
        time_desc: nil,
        typicality: 1,
        sort_order: 101,
        representative_trip_id: "trip id"
      }

      State.RoutePattern.new_state([route_pattern])

      response = get(conn, route_pattern_path(conn, :index))
      assert validate_resp_schema(response, schema, "RoutePatterns")
    end

    test "can filter by multiple ids", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1"},
        %RoutePattern{id: "rp2"},
        %RoutePattern{id: "rp3"}
      ])

      conn = get(conn, route_pattern_path(conn, :index, %{"filter" => %{"id" => "rp1,rp2"}}))

      assert [%{"id" => "rp1"}, %{"id" => "rp2"}] = json_response(conn, 200)["data"]
    end

    test "can filter by route", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", route_id: "route12"},
        %RoutePattern{id: "rp2", route_id: "route12"},
        %RoutePattern{id: "rp3", route_id: "route3"},
        %RoutePattern{id: "rp4", route_id: "route4"}
      ])

      conn =
        get(conn, route_pattern_path(conn, :index, %{"filter" => %{"route" => "route12,route3"}}))

      assert [%{"id" => "rp1"}, %{"id" => "rp2"}, %{"id" => "rp3"}] =
               json_response(conn, 200)["data"]
    end

    test "can filter by route and direction", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", route_id: "route12", direction_id: 0},
        %RoutePattern{id: "rp2", route_id: "route12", direction_id: 1},
        %RoutePattern{id: "rp3", route_id: "route3", direction_id: 0},
        %RoutePattern{id: "rp4", route_id: "route4", direction_id: 1}
      ])

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, %{
            "filter" => %{"route" => "route12,route3", "direction_id" => "0"}
          })
        )

      assert [
               %{
                 "id" => "rp1",
                 "relationships" => %{"route" => %{"data" => %{"id" => "route12"}}},
                 "attributes" => %{"direction_id" => 0}
               },
               %{
                 "id" => "rp3",
                 "relationships" => %{"route" => %{"data" => %{"id" => "route3"}}},
                 "attributes" => %{"direction_id" => 0}
               }
             ] = json_response(conn, 200)["data"]
    end

    test "can include route and trip", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp", route_id: "routeid", representative_trip_id: "tripid"}
      ])

      State.Route.new_state([
        %Route{id: "routeid"}
      ])

      State.Trip.new_state([
        %Trip{id: "tripid"}
      ])

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, include: "route,representative_trip")
        )

      response = json_response(conn, 200)
      assert [%{"type" => "route_pattern", "id" => "rp"}] = response["data"]

      assert [
               %{"type" => "route", "id" => "routeid"},
               %{"type" => "trip", "id" => "tripid"}
             ] = response["included"]

      [%{"relationships" => relationships}] = response["data"]

      assert %{
               "representative_trip" => %{"data" => %{"id" => "tripid", "type" => "trip"}},
               "route" => %{"data" => %{"id" => "routeid", "type" => "route"}}
             } == relationships
    end

    test "pagination", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", sort_order: 1},
        %RoutePattern{id: "rp2", sort_order: 2},
        %RoutePattern{id: "rp3", sort_order: 3}
      ])

      params = %{"page" => %{"offset" => 2, "limit" => 1}}
      conn = get(conn, route_pattern_path(conn, :index, params))

      response = json_response(conn, 200)
      assert [%{"id" => "rp3"}] = response["data"]
    end

    test "pagination can override default ordering", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", sort_order: 1},
        %RoutePattern{id: "rp2", sort_order: 2},
        %RoutePattern{id: "rp3", sort_order: 3}
      ])

      params = %{"page" => %{"offset" => 2, "limit" => 1}, "sort" => "-sort_order"}
      conn = get(conn, route_pattern_path(conn, :index, params))

      response = json_response(conn, 200)
      assert [%{"id" => "rp1"}] = response["data"]
    end

    test "returns 404 for newer API keys and old URL", %{swagger_schema: schema, conn: conn} do
      conn = assign(conn, :api_version, "2019-07-01")
      response = get(conn, "/route-patterns/")
      assert json_response(response, 404)
      assert validate_resp_schema(response, schema, "NotFound")
    end
  end

  describe "show" do
    test "shows chosen resource", %{conn: conn} do
      route_pattern = %RoutePattern{
        id: "route pattern id",
        route_id: "route id",
        direction_id: 0,
        name: "route pattern name",
        time_desc: nil,
        typicality: 1,
        sort_order: 101,
        representative_trip_id: "trip id"
      }

      State.RoutePattern.new_state([route_pattern])
      conn = get(conn, route_pattern_path(conn, :show, route_pattern))

      assert json_response(conn, 200)["data"] == %{
               "type" => "route_pattern",
               "id" => "route pattern id",
               "attributes" => %{
                 "direction_id" => 0,
                 "name" => "route pattern name",
                 "time_desc" => nil,
                 "typicality" => 1,
                 "sort_order" => 101
               },
               "links" => %{
                 "self" => "/route_patterns/route pattern id"
               },
               "relationships" => %{
                 "route" => %{
                   "data" => %{
                     "id" => "route id",
                     "type" => "route"
                   }
                 },
                 "representative_trip" => %{
                   "data" => %{
                     "id" => "trip id",
                     "type" => "trip"
                   }
                 }
               }
             }
    end

    test "does not allow filtering", %{conn: conn} do
      route_pattern = %RoutePattern{id: "1"}
      State.RoutePattern.new_state([route_pattern])

      conn = get(conn, route_pattern_path(conn, :show, route_pattern, %{"filter[route]" => "1"}))
      assert json_response(conn, 400)
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      route_pattern = %RoutePattern{
        id: "route pattern id",
        route_id: "route id",
        direction_id: 0,
        name: "route pattern name",
        time_desc: nil,
        typicality: 1,
        sort_order: 101,
        representative_trip_id: "trip id"
      }

      State.RoutePattern.new_state([route_pattern])
      response = get(conn, route_pattern_path(conn, :show, route_pattern))

      assert validate_resp_schema(response, schema, "RoutePattern")
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: swagger_shema
    } do
      conn = get(conn, route_pattern_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, swagger_shema, "NotFound")
    end

    test "returns 404 for newer API keys and old URL", %{swagger_schema: schema, conn: conn} do
      route_pattern = %RoutePattern{id: "1"}
      State.RoutePattern.new_state([route_pattern])
      conn = assign(conn, :api_version, "2019-07-01")
      response = get(conn, "/route-patterns/1")
      assert json_response(response, 404)
      assert validate_resp_schema(response, schema, "NotFound")
    end
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /route_patterns" do
      assert %{"/route_patterns" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               ApiWeb.RoutePatternController.swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /route_patterns/{id}" do
      assert %{
               "/route_patterns/{id}" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{},
                     "404" => %{}
                   }
                 }
               }
             } = ApiWeb.RoutePatternController.swagger_path_show(%{})
    end
  end
end
