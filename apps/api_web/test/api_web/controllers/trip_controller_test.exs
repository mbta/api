defmodule ApiWeb.TripControllerTest do
  use ApiWeb.ConnCase
  import ApiWeb.TripController
  alias Model.Trip

  setup %{conn: conn} do
    State.Trip.new_state([])

    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index/2" do
    test "returns 400 with invalid sort key", %{conn: conn} do
      trips =
        for i <- 1..2 do
          %Trip{id: "#{i}", route_id: "#{i}"}
        end

      :ok = State.Trip.new_state(trips)

      conn = get(conn, trip_path(conn, :index, %{"route" => "1,2", "sort" => "invalid"}))

      assert %{"errors" => [error]} = json_response(conn, 400)
      assert error["detail"] == "Invalid sort key."
    end

    test "returns a 400 with no filters", %{conn: conn} do
      conn = get(conn, trip_path(conn, :index))

      assert json_response(conn, 400)["errors"] == [
               %{
                 "status" => "400",
                 "code" => "bad_request",
                 "detail" => "At least one filter[] is required."
               }
             ]
    end

    test "rejects including occupancies without experimental header flag", %{conn: conn} do
      conn = get(conn, trip_path(conn, :index, %{"route" => "1", "include" => "occupancies"}))
      assert json_response(conn, 400)
    end

    test "accepts including occupancies with experimental header flag", %{conn: conn} do
      conn =
        conn
        |> put_req_header("x-enable-experimental-features", "true")
        |> get(trip_path(conn, :index, %{"route" => "1,2", "include" => "occupancies"}))

      assert json_response(conn, 200)
    end
  end

  describe "index_data/2" do
    test "returns an error with no filters", %{conn: conn} do
      assert index_data(conn, %{}) == {:error, :filter_required}
    end

    test "filters by route", %{conn: base_conn} do
      trip = %Model.Trip{id: "1", route_id: "2"}
      State.Trip.new_state([trip])

      # Sanity checks
      [] = State.Trip.filter_by(%{routes: ["1"]})
      [^trip] = State.Trip.filter_by(%{routes: ["2"]})

      conn = get(base_conn, trip_path(base_conn, :index, route: "1"))
      assert json_response(conn, 200)["data"] == []

      conn = get(base_conn, trip_path(base_conn, :index, route: "2"))
      response = json_response(conn, 200)["data"]
      assert List.first(response)["id"] == "1"

      sorted_results =
        conn
        |> index_data(%{"route" => "2,3"})
        |> Enum.sort(&(&1.id < &2.id))

      assert sorted_results == [trip]
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      route = %Model.Route{id: "1"}

      service = %Model.Service{
        id: "service",
        start_date: Timex.now(),
        end_date: Timex.end_of_day(Timex.now())
      }

      shape = %Model.Shape{id: "shape", route_id: "1"}

      trip = %Model.Trip{
        id: "10",
        route_id: "1",
        headsign: "Harvard",
        name: "1 Bus to Harvard",
        direction_id: 1,
        block_id: "",
        wheelchair_accessible: 1,
        service_id: "service",
        shape_id: "shape",
        bikes_allowed: 0,
        route_pattern_id: "1-1-1"
      }

      State.Route.new_state([route])
      State.Shape.new_state([shape])
      State.Service.new_state([service])
      State.Trip.new_state([trip])

      response = get(conn, trip_path(conn, :index, %{"route" => "1"}))

      assert validate_resp_schema(response, schema, "Trips")
    end

    test "filters by multiple ids", %{conn: conn} do
      trip1 = %Model.Trip{id: "1", route_id: "2", direction_id: 1}
      trip2 = %Model.Trip{id: "2", route_id: "2", direction_id: 1}
      trip3 = %Model.Trip{id: "3", route_id: "2", direction_id: 1}
      :ok = State.Trip.new_state([trip1, trip2, trip3])

      assert index_data(conn, %{"id" => "1,2"}) == [trip1, trip2]
    end

    test "filters by multiple ids and route id", %{conn: conn} do
      trip1 = %Model.Trip{id: "1", route_id: "1", direction_id: 1}
      trip2 = %Model.Trip{id: "2", route_id: "2", direction_id: 1}
      trip3 = %Model.Trip{id: "3", route_id: "3", direction_id: 1}
      :ok = State.Trip.new_state([trip1, trip2, trip3])

      assert index_data(conn, %{"id" => "1,2", "route" => "2,3"}) == [trip2]
      assert index_data(conn, %{"id" => "1,2,3", "route" => "2"}) == [trip2]
      assert index_data(conn, %{"id" => "1,2,3", "route" => "4"}) == []
    end

    test "filters by route and direction_id", %{conn: conn} do
      trip = %Model.Trip{id: "1", route_id: "2", direction_id: 1}
      :ok = State.Trip.new_state([trip])

      assert index_data(conn, %{"route" => "2", "direction_id" => "1"}) == [trip]
      assert index_data(conn, %{"route" => "2", "direction_id" => "0"}) == []
    end

    test "filters by name", %{conn: conn} do
      trip = %Model.Trip{id: "1", name: "name"}
      :ok = State.Trip.new_state([trip])

      assert index_data(conn, %{"name" => "name"}) == [trip]
      assert index_data(conn, %{"name" => "not_a_name"}) == []
      assert index_data(conn, %{"name" => ""}) == {:error, :filter_required}
      assert index_data(conn, %{"name" => ","}) == {:error, :filter_required}
    end

    test "filters by date", %{conn: conn} do
      today = Parse.Time.service_date()
      bad_date = %{today | year: today.year - 1}

      service = %Model.Service{
        id: "service",
        start_date: today,
        end_date: today,
        added_dates: [today]
      }

      trip = %Model.Trip{id: "1", route_id: "2", service_id: "service"}

      State.Service.new_state([service])
      State.Trip.reset_gather()
      State.Trip.new_state([trip])

      params = %{"route" => "2"}
      good_date_params = Map.put(params, "date", Date.to_iso8601(today))
      bad_date_params = Map.put(params, "date", Date.to_iso8601(bad_date))

      assert index_data(conn, good_date_params) == [trip]
      assert index_data(conn, bad_date_params) == []
    end

    test "when there are alternate trips, returns the primary", %{conn: conn} do
      trips = [
        %Model.Trip{id: "1", route_id: "3", alternate_route: true},
        trip = %Model.Trip{id: "1", route_id: "4", alternate_route: false}
      ]

      State.Trip.new_state(trips)

      [^trip] = State.Trip.filter_by(%{routes: ["3"]})

      results = index_data(conn, %{"route" => "3"})
      assert List.first(results).id == "1"
      assert List.first(results).route_id == "4"
    end

    test "can be paginated and sorted", %{conn: conn} do
      trips =
        for i <- 1..9 do
          %Trip{id: "#{i}", route_id: "#{i}"}
        end

      alt_trips =
        for i <- 1..9 do
          %Trip{id: "#{i}", route_id: "#{i + 10}", alternate_route: true}
        end

      :ok = State.Trip.new_state(trips ++ alt_trips)

      trip2 = Enum.at(trips, 1)
      trip3 = Enum.at(trips, 2)
      trip7 = Enum.at(trips, 6)
      trip8 = Enum.at(trips, 7)

      route_ids = ["1", "2", "13", "4", "5", "7", "8", "19"]

      params = %{
        "route" => Enum.join(route_ids, ","),
        "page" => %{"offset" => 1, "limit" => 2}
      }

      {data, _} = index_data(conn, Map.merge(params, %{"sort" => "id"}))
      assert data == [trip2, trip3]
      {data, _} = index_data(conn, Map.merge(params, %{"sort" => "-id"}))
      assert data == [trip8, trip7]
    end

    test "returns error tuple with invalid sort key", %{conn: conn} do
      trips =
        for i <- 1..2 do
          %Trip{id: "#{i}", route_id: "#{i}"}
        end

      :ok = State.Trip.new_state(trips)

      assert index_data(conn, %{"route" => "1,2", "sort" => "invalid"}) ==
               {:error, :invalid_order_by}
    end

    test "filter by revenue status", %{conn: conn} do
      trip1 = %Model.Trip{id: "1", route_id: "1", direction_id: 1, revenue_service: true}
      trip2 = %Model.Trip{id: "2", route_id: "2", direction_id: 1, revenue_service: false}
      trip3 = %Model.Trip{id: "3", route_id: "3", direction_id: 1, revenue_service: true}
      :ok = State.Trip.new_state([trip1, trip2, trip3])

      assert index_data(conn, %{"revenue_status" => "all"}) == [trip1, trip2, trip3]
      assert index_data(conn, %{"revenue_status" => "revenue"}) == [trip1, trip3]
      assert index_data(conn, %{"revenue_status" => "non_revenue"}) == [trip2]
      assert index_data(conn, %{"route" => "1", "revenue_status" => "all"}) == [trip1]
      assert index_data(conn, %{"route" => "1", "revenue_status" => "revenue"}) == [trip1]
      assert index_data(conn, %{"route" => "1", "revenue_status" => "non_revenue"}) == []
    end
  end

  describe "show" do
    test "shows chosen resource", %{conn: base_conn} do
      trip = %Model.Trip{id: "1"}
      State.Trip.new_state([trip])

      conn = get(base_conn, trip_path(base_conn, :show, trip.id))
      assert json_response(conn, 200)["data"]["id"] == trip.id
    end

    test "returns an error with invalid includes", %{conn: conn} do
      conn = get(conn, trip_path(conn, :show, "id"), include: "invalid")

      assert get_in(json_response(conn, 400), ["errors", Access.at(0), "source", "parameter"]) ==
               "include"
    end

    test "including predictions", %{conn: conn} do
      trip = %Model.Trip{id: "trip"}

      prediction = %Model.Prediction{
        trip_id: "trip",
        route_id: "route",
        stop_id: "stop"
      }

      State.Trip.new_state([trip])
      State.Prediction.new_state([prediction])

      conn =
        get(
          conn,
          trip_path(
            conn,
            :show,
            trip.id,
            include: "predictions"
          )
        )

      assert %{
               "id" => "trip",
               "relationships" => %{
                 "predictions" => %{
                   "data" => [%{"id" => "prediction-trip-stop-", "type" => "prediction"}]
                 }
               }
             } = json_response(conn, 200)["data"]
    end

    test "including occupancies", %{conn: conn} do
      trip = %Model.Trip{id: "trip", name: "trip_name"}

      occupancy = %Model.CommuterRailOccupancy{
        trip_name: "trip_name",
        status: :full,
        percentage: 99
      }

      State.Trip.new_state([trip])
      State.CommuterRailOccupancy.new_state([occupancy])

      conn =
        conn
        |> put_req_header("x-enable-experimental-features", "true")
        |> get(trip_path(conn, :show, trip.id), include: "occupancies")

      assert %{
               "data" => %{
                 "id" => "trip",
                 "relationships" => %{
                   "occupancies" => %{
                     "data" => [%{"id" => "occupancy-trip_name", "type" => "occupancy"}]
                   }
                 }
               },
               "included" => [
                 %{
                   "id" => "occupancy-trip_name",
                   "attributes" => %{"percentage" => 99, "status" => "FULL"}
                 }
               ]
             } = json_response(conn, 200)
    end

    test "does not allow filtering", %{conn: conn} do
      trip = %Model.Trip{id: "trip"}

      State.Trip.new_state([trip])

      conn = get(conn, trip_path(conn, :show, trip.id, %{"filter[route]" => "1"}))
      assert json_response(conn, 400)
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      route = %Model.Route{id: "1"}

      service = %Model.Service{
        id: "service",
        start_date: Timex.now(),
        end_date: Timex.end_of_day(Timex.now())
      }

      shape = %Model.Shape{id: "shape", route_id: "1"}

      trip = %Model.Trip{
        id: "10",
        route_id: "1",
        headsign: "Harvard",
        name: "1 Bus to Harvard",
        direction_id: 1,
        block_id: "",
        wheelchair_accessible: 1,
        service_id: "service",
        shape_id: "shape",
        bikes_allowed: 0,
        route_pattern_id: "1-1-1"
      }

      State.Route.new_state([route])
      State.Shape.new_state([shape])
      State.Service.new_state([service])
      State.Trip.new_state([trip])

      response = get(conn, trip_path(conn, :show, "10"))

      assert validate_resp_schema(response, schema, "Trip")
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: schema
    } do
      conn = get(conn, trip_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, schema, "NotFound")
    end
  end

  test "state_module/0" do
    assert State.Trip.Added == ApiWeb.TripController.state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /trips" do
      assert %{"/trips" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /trips/{id}" do
      assert %{
               "/trips/{id}" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{},
                     "404" => %{}
                   }
                 }
               }
             } = swagger_path_show(%{})
    end
  end
end
