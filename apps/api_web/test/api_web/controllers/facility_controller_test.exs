defmodule ApiWeb.FacilityControllerTest do
  use ApiWeb.ConnCase

  import ApiWeb.FacilityController
  alias Model.Facility

  setup %{conn: conn} do
    State.Facility.new_state([
      %Facility{
        id: "6",
        long_name: "name",
        short_name: "short_name",
        type: "ELEVATOR",
        stop_id: "place-qnctr",
        latitude: 42.260381,
        longitude: -71.794593
      },
      %Facility{
        id: "7",
        long_name: "name",
        short_name: "short_name",
        type: "ESCALATOR",
        stop_id: "place-alfcl",
        latitude: 42.260381,
        longitude: -71.794593
      },
      %Facility{
        id: "8",
        long_name: "name",
        short_name: "short_name",
        type: "ESCALATOR",
        stop_id: "place-qnctr",
        latitude: 42.260381,
        longitude: -71.794593
      }
    ])

    {:ok, conn: conn}
  end

  describe "index" do
    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, facility_path(conn, :index))

      assert validate_resp_schema(response, schema, "Facilities")
    end

    test "can get with sparse fieldset", %{conn: conn} do
      conn = get(conn, facility_path(conn, :index), fields: %{facility: "type"})

      keys =
        json_response(conn, 200)["data"]
        |> hd()
        |> Map.get("attributes")
        |> Map.keys()

      assert keys == ["type"]
    end
  end

  describe "index_data" do
    test "can filter by type", %{conn: conn} do
      facility_1 = State.Facility.by_id("7")
      facility_2 = State.Facility.by_id("8")
      results = index_data(conn, %{"filter" => %{"type" => "ESCALATOR"}})
      assert results == [facility_1, facility_2]
    end

    test "can filter by stop_id", %{conn: conn} do
      facility_1 = State.Facility.by_id("7")
      results = index_data(conn, %{"filter" => %{"stop" => "place-alfcl"}})
      assert results == [facility_1]
    end

    test "returns errors for invalid filters", %{conn: conn} do
      results = index_data(conn, %{"filter" => %{"stop" => "place-alfcl", "id" => "ignored"}})
      assert results == {:error, :bad_filter, ~w(id)}
    end

    test "can filter by stop_id and type", %{conn: conn} do
      facility_1 = State.Facility.by_id("6")
      facility_2 = State.Facility.by_id("7")
      facility_3 = State.Facility.by_id("8")
      results = index_data(conn, %{"filter" => %{"stop" => "place-qnctr", "type" => "ESCALATOR"}})
      assert Enum.sort(results) == [facility_1, facility_2, facility_3]
    end
  end

  describe "show" do
    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, facility_path(conn, :show, "6"))

      assert validate_resp_schema(response, schema, "Facility")
    end

    test "does not allow filtering", %{conn: conn} do
      facility = %Facility{id: "1"}
      State.Facility.new_state([facility])

      response = get(conn, facility_path(conn, :show, facility.id, %{"filter[stop]" => "1"}))
      assert json_response(response, 400)
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: swagger_schema
    } do
      conn = get(conn, alert_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, swagger_schema, "NotFound")
    end
  end

  test "state_module/0" do
    assert State.Facility == state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /facilities" do
      assert %{"/facilities" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /facilities/{id}" do
      assert %{
               "/facilities/{id}" => %{
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
