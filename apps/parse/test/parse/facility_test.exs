defmodule Parse.FacilityTest do
  use ExUnit.Case, async: true
  import Parse.Facility
  alias Model.Facility

  setup do
    blob = ~s(
"facility_id","facility_code","facility_class","facility_type","stop_id","facility_short_name","facility_long_name","facility_desc","facility_lat","facility_lon","wheelchair_facility"
"pick-qnctr-busway","","3","pick-drop","place-qnctr","Hancock Street","Quincy Center Hancock Street Pick-up/Drop-off","","42.251716","-71.004715","1"
)

    {:ok, %{blob: blob}}
  end

  describe "parse/1" do
    test "parses a CSV blob into a list of %Facility{} structs", %{blob: blob} do
      assert parse(blob) == [
               %Facility{
                 id: "pick-qnctr-busway",
                 stop_id: "place-qnctr",
                 type: "PICK_DROP",
                 name: "Quincy Center Hancock Street Pick-up/Drop-off",
                 latitude: 42.251716,
                 longitude: -71.004715
               }
             ]
    end
  end
end
