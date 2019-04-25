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

  setup do
    State.Facility.Parking.new_state(@properties)

    :ok
  end

  describe "index_data/2" do
    test "without a filter, returns an error", %{conn: conn} do
      assert index_data(conn, %{}) == {:error, :filter_required}
    end

    test "with an ID filter, returns the properties for that facility", %{conn: conn} do
      assert [actual] = index_data(conn, %{"filter" => %{"id" => "not_valid,#{@facility_id}"}})
      assert_valid_live_facility(actual)
    end

    test "with an ID filter, does not return properties for other facilities", %{conn: conn} do
      assert index_data(conn, %{"filter" => %{"id" => "not_valid"}}) == []
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

      assert [%{facility_id: @facility_id}, %{facility_id: ^other_facility}] =
               index_data(conn, Map.put(base_filter, "sort", "updated_at"))

      assert [%{facility_id: ^other_facility}, %{facility_id: @facility_id}] =
               index_data(conn, Map.put(base_filter, "sort", "-updated_at"))
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
      actual = show_data(conn, %{"id" => @facility_id})
      assert_valid_live_facility(actual)
    end

    test "returns nil if the facility doesn't have any properties", %{conn: conn} do
      assert show_data(conn, %{"id" => "live_facility_controller_does_not_exist"}) == nil
    end
  end

  describe "show/2" do
    test "does not allow filtering", %{conn: conn} do
      response =
        get(conn, live_facility_path(conn, :show, @facility_id, %{"filter[id]" => @facility_id}))

      assert json_response(response, 400)
    end
  end

  defp assert_valid_live_facility(actual) do
    assert %{
             facility_id: @facility_id,
             properties: [_, _]
           } = actual

    for property <- @properties do
      assert property in actual.properties
    end
  end
end
