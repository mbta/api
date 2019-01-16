defmodule Parse.Facility.PropertyTest do
  use ExUnit.Case, async: true
  import Parse.Facility.Property
  alias Model.Facility.Property

  describe "parse/1" do
    test "parses a CSV blob into a list of %Facility.Property{} structs" do
      blob = ~s(
"facility_id","property_id","value"
"park-001","enclosed","2")

      assert parse(blob) == [
               %Property{
                 name: "enclosed",
                 facility_id: "park-001",
                 value: 2
               }
             ]
    end

    test "doesn't decode non-numeric values" do
      blob = ~s(
"facility_id","property_id","value"
"park-001","operator","Republic Parking System")

      assert parse(blob) == [
               %Property{
                 name: "operator",
                 facility_id: "park-001",
                 value: "Republic Parking System"
               }
             ]
    end
  end
end
