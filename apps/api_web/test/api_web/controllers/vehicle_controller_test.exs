defmodule ApiWeb.VehicleControllerTest do
  use ApiWeb.ConnCase
  import ApiWeb.VehicleController
  alias Model.{Route, Trip, Vehicle}

  @moduletag vehicles: true

  @route %Route{
    id: "CR-Haverhill",
    type: 2
  }
  @route_alt %Route{
    id: "CR-Lowell"
  }
  @trips_base for i <- 1..9,
                  do: %Trip{
                    id: "#{i}",
                    route_id: @route.id,
                    direction_id: 1,
                    alternate_route: false
                  }
  @trip_alt %Trip{
    id: "9",
    route_id: @route_alt.id,
    direction_id: 1,
    alternate_route: true
  }
  @trips @trips_base ++ [@trip_alt]
  {:ok, updated_at, 0} = DateTime.from_iso8601("1952-05-27T03:05:07Z")

  @vehicles for i <- 1..9,
                do: %Vehicle{
                  id: "vehicle_#{i}",
                  trip_id: "#{i}",
                  route_id: @route.id,
                  effective_route_id: @route.id,
                  direction_id: 1,
                  bearing: 5,
                  current_status: :in_transit_to,
                  current_stop_sequence: 3,
                  label: "#{i}",
                  updated_at: updated_at,
                  latitude: 42.01,
                  longitude: -71.15,
                  speed: 75,
                  stop_id: "current_stop",
                  occupancy_status: :empty,
                  carriages: [
                    %Vehicle.Carriage{
                      label: "carriage_1",
                      occupancy_status: :empty,
                      occupancy_percentage: 0,
                      carriage_sequence: 1
                    },
                    %Vehicle.Carriage{
                      label: "carriage_2",
                      occupancy_status: :empty,
                      occupancy_percentage: 0,
                      carriage_sequence: 2
                    }
                  ]
                }
  @stop %Model.Stop{id: "current_stop"}
  @vehicle hd(@vehicles)

  setup %{conn: conn} do
    State.Route.new_state([@route, @route_alt])
    State.Trip.new_state(@trips)
    State.Vehicle.new_state(@vehicles)
    State.Stop.new_state([@stop])
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index_data/2" do
    test "lists all entries on index", %{conn: conn} do
      assert index_data(conn, %{}) == State.Vehicle.all()
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, vehicle_path(conn, :index))

      assert validate_resp_schema(response, schema, "Vehicles")
    end

    test "can filter by ID", %{conn: conn} do
      assert index_data(conn, %{"id" => "vehicle_1,vehicle_9"}) == [
               @vehicle,
               List.last(@vehicles)
             ]
    end

    test "can filter by trip", %{conn: conn} do
      for vehicle <- @vehicles do
        vehicle_id = vehicle.id
        assert [%Vehicle{id: ^vehicle_id}] = index_data(conn, %{"trip" => vehicle.trip_id})

        assert [%Vehicle{id: ^vehicle_id}] =
                 index_data(conn, %{"trip" => "#{vehicle.trip_id},not_a_trip"})
      end

      assert index_data(conn, %{"trip" => "not_a_trip"}) == []
    end

    test "can filter by route", %{conn: conn} do
      State.Vehicle.new_state([@vehicle])

      assert index_data(conn, %{"route" => @route.id}) == [@vehicle]
      assert index_data(conn, %{"route" => "#{@route.id},not_a_route"}) == [@vehicle]
      assert index_data(conn, %{"route" => "not_a_route"}) == []
    end

    test "can filter by route and direction_id", %{conn: conn} do
      State.Vehicle.new_state([@vehicle])

      assert index_data(conn, %{"route" => @route.id, "direction_id" => "1"}) == [@vehicle]
      assert index_data(conn, %{"route" => @route.id, "direction_id" => "0"}) == []
    end

    test "can filter by route that's the alternate", %{conn: conn} do
      assert [vehicle] = index_data(conn, %{"route" => @route_alt.id})
      assert vehicle.route_id == @route.id
    end

    test "can filter by label", %{conn: conn} do
      for vehicle <- @vehicles do
        assert index_data(conn, %{"label" => vehicle.label}) == [vehicle]
        assert index_data(conn, %{"label" => "#{vehicle.label},not_a_label"}) == [vehicle]
      end

      assert index_data(conn, %{"label" => "not_a_label"}) == []
    end

    test "can filter by label and route", %{conn: conn} do
      for vehicle <- @vehicles do
        assert index_data(conn, %{"label" => vehicle.label, "route" => vehicle.route_id}) == [
                 vehicle
               ]

        assert index_data(conn, %{"label" => "not_a_label", "route" => vehicle.route_id}) == []
        assert index_data(conn, %{"label" => vehicle.label, "route" => "not_a_route"}) == []
      end

      assert index_data(conn, %{"label" => "not_a_label", "route" => "not_a_route"}) == []
    end

    test "can filter by label, route and direction_id", %{conn: conn} do
      for vehicle <- @vehicles do
        assert index_data(conn, %{
                 "label" => vehicle.label,
                 "route" => vehicle.route_id,
                 "direction_id" => "1"
               }) == [vehicle]

        assert index_data(conn, %{
                 "label" => vehicle.label,
                 "route" => vehicle.route_id,
                 "direction_id" => "0"
               }) == []
      end
    end

    test "can filter by route_type", %{conn: conn} do
      State.Vehicle.new_state([@vehicle])

      assert index_data(conn, %{"route_type" => "0,1"}) == []
      assert index_data(conn, %{"route_type" => "2"}) == [@vehicle]
    end

    test "can filter by route and route_type", %{conn: conn} do
      State.Vehicle.new_state([@vehicle])

      assert index_data(conn, %{"route" => "CR-Haverhill", "route_type" => "2"}) == [@vehicle]
      assert index_data(conn, %{"route" => "CR-Haverhill", "route_type" => "0,1"}) == []
    end

    test "can filter by route_type, route and direction_id", %{conn: conn} do
      State.Vehicle.new_state([@vehicle])

      assert index_data(conn, %{
               "route" => "CR-Haverhill",
               "route_type" => "2",
               "direction_id" => "1"
             }) == [@vehicle]

      assert index_data(conn, %{
               "route" => "CR-Haverhill",
               "route_type" => "2",
               "direction_id" => "0"
             }) == []
    end

    test "does not crash when only direction_id filter is given", %{conn: conn} do
      State.Vehicle.new_state([@vehicle])

      assert index_data(conn, %{"direction_id" => "1"}) == [@vehicle]
    end

    test "can be paginated and sorted", %{conn: conn} do
      vehicle2 = Enum.at(@vehicles, 1)
      vehicle3 = Enum.at(@vehicles, 2)
      vehicle7 = Enum.at(@vehicles, 6)
      vehicle8 = Enum.at(@vehicles, 7)
      params = %{"page" => %{"offset" => 1, "limit" => 2}}

      {[^vehicle2, ^vehicle3], _} = State.Vehicle.all(offset: 1, limit: 2, order_by: {:id, :asc})
      {[^vehicle8, ^vehicle7], _} = State.Vehicle.all(offset: 1, limit: 2, order_by: {:id, :desc})

      {data, _} = index_data(conn, Map.merge(params, %{"sort" => "id"}))
      assert data == [vehicle2, vehicle3]

      {data, _} = index_data(conn, Map.merge(params, %{"sort" => "-id"}))
      assert data == [vehicle8, vehicle7]
    end

    test "can filter along with pagination", %{conn: conn} do
      vehicle4 = Enum.at(@vehicles, 3)
      vehicle5 = Enum.at(@vehicles, 4)
      params = %{"page" => %{"limit" => 1}, "trip" => "5,4"}

      {data, _} = index_data(conn, Map.merge(params, %{"sort" => "id"}))
      assert data == [vehicle4]
      {data, _} = index_data(conn, Map.merge(params, %{"sort" => "-id"}))
      assert data == [vehicle5]

      params = %{"page" => %{"limit" => 1}, "route" => @route.id}

      {data, _} = index_data(conn, Map.merge(params, %{"sort" => "id"}))
      assert data == [@vehicle]
    end

    test "backwards compatibility: sorting by last_updated is the same as updated_at", %{
      conn: conn
    } do
      legacy_conn = assign(conn, :api_version, "2017-11-28")
      newer_vehicle = %{Enum.at(@vehicles, 1) | id: "new", updated_at: DateTime.utc_now()}
      State.Vehicle.new_state([@vehicle, newer_vehicle])

      assert index_data(legacy_conn, %{"sort" => "last_updated"}) == [@vehicle, newer_vehicle]
      assert index_data(legacy_conn, %{"sort" => "-last_updated"}) == [newer_vehicle, @vehicle]

      conn = assign(conn, :api_version, "2018-05-07")
      assert {:error, _} = index_data(conn, %{"sort" => "last_updated"})
    end
  end

  describe "show" do
    test "shows chosen resource", %{conn: conn} do
      State.Trip.new_state([%Model.Trip{id: "2"}])
      vehicle = %Vehicle{id: "1", trip_id: "2"}
      State.Vehicle.new_state([vehicle])

      conn = get(conn, vehicle_path(conn, :show, vehicle))

      assert json_response(conn, 200)["data"] == %{
               "type" => "vehicle",
               "id" => vehicle.id,
               "links" => %{
                 "self" => "/vehicles/1"
               },
               "relationships" => %{
                 "stop" => %{"data" => nil},
                 "route" => %{"data" => nil},
                 "trip" => %{"data" => %{"type" => "trip", "id" => "2"}}
               },
               "attributes" => %{
                 "bearing" => nil,
                 "latitude" => nil,
                 "longitude" => nil,
                 "speed" => nil,
                 "label" => nil,
                 "direction_id" => nil,
                 "current_status" => nil,
                 "current_stop_sequence" => nil,
                 "updated_at" => nil,
                 "occupancy_status" => nil,
                 "carriages" => []
               }
             }
    end

    test "does not allow filtering", %{conn: conn} do
      State.Trip.new_state([%Model.Trip{id: "2"}])
      vehicle = %Vehicle{id: "1", trip_id: "2"}
      State.Vehicle.new_state([vehicle])
      conn = get(conn, vehicle_path(conn, :show, vehicle, %{"filter[label]" => "1"}))
      assert json_response(conn, 400)
    end

    test "returns an error with invalid includes", %{conn: conn} do
      conn = get(conn, vehicle_path(conn, :show, "id"), include: "invalid")

      assert get_in(json_response(conn, 400), ["errors", Access.at(0), "source", "parameter"]) ==
               "include"
    end

    test "version 2018-05-07 does not include last_updated", %{conn: conn} do
      vehicle = %Vehicle{id: "1", trip_id: "2"}
      State.Vehicle.new_state([vehicle])

      response =
        conn
        |> assign(:api_version, "2018-05-07")
        |> get(vehicle_path(conn, :show, vehicle.id))
        |> json_response(200)

      refute "last_updated" in Map.keys(response["data"]["attributes"])
    end

    test "version 2017-11-28 does include last_updated", %{conn: conn} do
      vehicle = %Vehicle{id: "1", trip_id: "2"}
      State.Vehicle.new_state([vehicle])

      response =
        conn
        |> assign(:api_version, "2017-11-28")
        |> get(vehicle_path(conn, :show, vehicle.id))
        |> json_response(200)

      assert "last_updated" in Map.keys(response["data"]["attributes"])
    end

    test "version 2017-11-28 can still filter out the legacy fields", %{conn: conn} do
      vehicle = %Vehicle{id: "1", trip_id: "2"}
      State.Vehicle.new_state([vehicle])

      response =
        conn
        |> assign(:api_version, "2017-11-28")
        |> get(vehicle_path(conn, :show, vehicle.id), fields: %{"vehicle" => ""})
        |> json_response(200)

      refute "last_updated" in Map.keys(response["data"]["attributes"])
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      State.Trip.new_state([%Model.Trip{id: "1"}])
      State.Stop.new_state([%Model.Stop{id: "current_stop"}])
      State.Route.new_state([@route])

      vehicle = %Vehicle{
        id: "vehicle_1",
        trip_id: "1",
        route_id: @route.id,
        effective_route_id: @route.id,
        direction_id: 1,
        bearing: 5,
        current_status: :in_transit_to,
        current_stop_sequence: 3,
        label: "In Transit",
        updated_at: "1952-05-27T03:05:07",
        latitude: 42.01,
        longitude: -71.15,
        speed: 75,
        stop_id: "current_stop",
        occupancy_status: :many_seats_available,
        carriages: [
          %Vehicle.Carriage{
            label: "carriage_1",
            occupancy_status: :empty,
            occupancy_percentage: 0,
            carriage_sequence: 1
          },
          %Vehicle.Carriage{
            label: "carriage_2",
            occupancy_status: :empty,
            occupancy_percentage: 0,
            carriage_sequence: 2
          }
        ]
      }

      State.Vehicle.new_state([vehicle])

      response = get(conn, vehicle_path(conn, :show, "vehicle_1"))
      assert validate_resp_schema(response, schema, "Vehicle")
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: swagger_shema
    } do
      conn = get(conn, vehicle_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, swagger_shema, "NotFound")
    end
  end

  test "state_module/0" do
    assert State.Vehicle == ApiWeb.VehicleController.state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /vehicles" do
      assert %{
               "/vehicles" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{}
                   }
                 }
               }
             } = ApiWeb.VehicleController.swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /vehicles/{id}" do
      assert %{
               "/vehicles/{id}" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{},
                     "404" => %{}
                   }
                 }
               }
             } = ApiWeb.VehicleController.swagger_path_show(%{})
    end
  end
end
