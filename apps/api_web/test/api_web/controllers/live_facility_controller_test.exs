defmodule ApiWeb.LiveFacilityControllerTest do
  use ApiWeb.ConnCase
  import ApiWeb.LiveFacilityController
  alias Model.Facility.Property

  @facility_id "live_facility_controller"
  @properties [
    %Property{
      facility_id: @facility_id,
      name: "one",
      value: 1,
      updated_at: DateTime.from_unix!(1_000_000_000)
    },
    %Property{
      facility_id: @facility_id,
      name: "two",
      value: "2",
      updated_at: DateTime.from_unix!(0)
    }
  ]

  setup %{conn: conn} do
    State.Facility.Parking.new_state(@properties)
    conn = assign(conn, :api_version, "2019-04-05")
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index_data/2" do
    test "without a filter, returns an error", %{conn: conn} do
      response = get(conn, live_facility_path(conn, :index))

      assert response = json_response(response, 400)

      assert response["errors"] == [
               %{
                 "code" => "bad_request",
                 "detail" => "At least one filter[] is required.",
                 "status" => "400"
               }
             ]
    end

    test "with an ID filter, returns the properties for that facility", %{conn: conn} do
      response =
        get(
          conn,
          live_facility_path(conn, :index, %{"filter" => %{"id" => "not_valid,#{@facility_id}"}})
        )

      assert json_response(response, 200)["data"] == [
               %{
                 "attributes" => %{
                   "properties" => [
                     %{"name" => "one", "value" => 1},
                     %{"name" => "two", "value" => "2"}
                   ],
                   "updated_at" => "2001-09-09T01:46:40Z"
                 },
                 "id" => "live_facility_controller",
                 "links" => %{
                   "self" => "/live_facilities/live_facility_controller"
                 },
                 "relationships" => %{
                   "facility" => %{
                     "data" => %{
                       "id" => "live_facility_controller",
                       "type" => "facility"
                     }
                   }
                 },
                 "type" => "live_facility"
               }
             ]
    end

    test "with an ID filter, does not return properties for other facilities", %{conn: conn} do
      response =
        get(conn, live_facility_path(conn, :index, %{"filter" => %{"id" => "not_valid"}}))

      assert json_response(response, 200)["data"] == []
    end

    test "can sort by updated time", %{conn: conn} do
      other_facility = "#{@facility_id}_other"

      other_properties = [
        %Property{
          facility_id: other_facility,
          name: "one",
          value: 1,
          updated_at: DateTime.from_unix!(2_000_000_000)
        }
      ]

      State.Facility.Parking.new_state(@properties ++ other_properties)

      base_filter = %{"filter" => %{"id" => "#{@facility_id},#{other_facility}"}}

      response =
        get(
          conn,
          live_facility_path(conn, :index, Map.put(base_filter, "sort", "updated_at"))
        )

      assert [%{"id" => @facility_id}, %{"id" => ^other_facility}] =
               json_response(response, 200)["data"]

      response =
        get(
          conn,
          live_facility_path(conn, :index, Map.put(base_filter, "sort", "-updated_at"))
        )

      assert [%{"id" => ^other_facility}, %{"id" => @facility_id}] =
               json_response(response, 200)["data"]
    end

    test "returns 404 for newer API keys and old URL", %{swagger_schema: schema, conn: conn} do
      conn = assign(conn, :api_version, "2019-07-01")
      response = get(conn, live_facility_path(conn, :index))
      assert json_response(response, 404)
      assert validate_resp_schema(response, schema, "NotFound")
    end
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /live-facilities" do
      assert %{"/live-facilities" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /live-facilities/{id}" do
      assert %{
               "/live-facilities/{id}" => %{
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

  describe "show_data/2" do
    test "returns the properties for a given facility", %{conn: conn} do
      response = get(conn, live_facility_path(conn, :show, @facility_id))

      assert json_response(response, 200)["data"] == %{
               "attributes" => %{
                 "properties" => [
                   %{"name" => "one", "value" => 1},
                   %{"name" => "two", "value" => "2"}
                 ],
                 "updated_at" => "2001-09-09T01:46:40Z"
               },
               "id" => "live_facility_controller",
               "links" => %{
                 "self" => "/live_facilities/live_facility_controller"
               },
               "relationships" => %{
                 "facility" => %{
                   "data" => %{
                     "id" => "live_facility_controller",
                     "type" => "facility"
                   }
                 }
               },
               "type" => "live_facility"
             }
    end

    test "returns nil if the facility doesn't have any properties", %{conn: conn} do
      assert show_data(conn, %{"id" => "live_facility_controller_does_not_exist"}) == nil
    end

    test "returns 404 for newer API keys and old URL", %{swagger_schema: schema, conn: conn} do
      conn = assign(conn, :api_version, "2019-07-01")
      response = get(conn, live_facility_path(conn, :show, @facility_id))
      assert json_response(response, 404)
      assert validate_resp_schema(response, schema, "NotFound")
    end
  end

  describe "show/2" do
    test "does not allow filtering", %{conn: conn} do
      response =
        get(conn, live_facility_path(conn, :show, @facility_id, %{"filter[id]" => @facility_id}))

      assert json_response(response, 400)
    end
  end
end
