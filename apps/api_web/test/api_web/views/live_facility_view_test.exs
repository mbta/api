defmodule ApiWeb.LiveFacilityViewTest do
  use ApiWeb.ConnCase, async: true
  import ApiWeb.LiveFacilityView
  alias Model.Facility.Property

  @facility_id "live_facility_view"
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
  @live_facility %{
    facility_id: @facility_id,
    properties: @properties,
    updated_at: "2001-09-09T01:46:40Z"
  }

  describe "id/2" do
    test "returns the facility ID", %{conn: conn} do
      assert id(@live_facility, conn) == @facility_id
    end
  end

  describe "facility/2" do
    test "returns the ID when nothing is included", %{conn: conn} do
      assert facility(@live_facility, conn) == @facility_id
    end

    test "returns the facility when it is included", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"include" => "facility"})
        |> ApiWeb.ApiControllerHelpers.split_include([])

      # since the facility doesn't exist, looking it up by ID returns `nil`
      assert facility(@live_facility, conn) == nil
    end
  end

  describe "attributes/2" do
    test "returns name/value/updated_at for each property", %{conn: conn} do
      expected = %{
        updated_at: "2001-09-09T01:46:40Z",
        properties: [
          %{
            name: "one",
            value: 1
          },
          %{
            name: "two",
            value: "2"
          }
        ]
      }

      actual = attributes(@live_facility, conn)
      assert actual == expected
    end
  end
end
