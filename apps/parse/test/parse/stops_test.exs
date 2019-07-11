defmodule Parse.StopsTest do
  use ExUnit.Case, async: true
  alias Model.Stop

  setup do
    blob = """
    "stop_id","stop_code","stop_name","stop_desc","platform_code","platform_name","stop_lat","stop_lon","stop_address","zone_id","stop_url","level_id","location_type","parent_station","wheelchair_boarding","municipality","on_street","at_street","vehicle_type"
    "place-alfcl","","Alewife","","","",42.395428,-71.142483,"Alewife Brook Parkway and Cambridge Park Drive, Cambridge, MA 02140","","","",1,"",1,"Cambridge","Alewife Brook Parkway","Cambridge Park Drive",1
    "70061","70061","Alewife","Alewife - Red Line","","Red Line",42.395428,-71.142483,"","","","",0,"place-alfcl",1,"Cambridge",,,1
    "Back Bay-01","","Back Bay","Back Bay - Commuter Rail - Track 1","1","Commuter Rail - Track 1",42.347283,-71.075312,"","CR-zone-1A","","",0,"place-bbsta",1,"Boston",,,2
    "node-bbsta","","Generic Node","Back Bay Generic Node",,,,,,,,,3,"place-bbsta",1,,,,
    """

    {:ok, %{blob: blob}}
  end

  test "parse: parses a CSV blob into a list of stops", %{blob: blob} do
    assert Parse.Stops.parse(blob) == [
             %Stop{
               id: "place-alfcl",
               name: "Alewife",
               address: "Alewife Brook Parkway and Cambridge Park Drive, Cambridge, MA 02140",
               latitude: 42.395428,
               longitude: -71.142483,
               wheelchair_boarding: 1,
               location_type: 1,
               zone_id: nil,
               municipality: "Cambridge",
               on_street: "Alewife Brook Parkway",
               at_street: "Cambridge Park Drive",
               vehicle_type: 1
             },
             %Stop{
               id: "70061",
               name: "Alewife",
               description: "Alewife - Red Line",
               platform_name: "Red Line",
               latitude: 42.395428,
               longitude: -71.142483,
               parent_station: "place-alfcl",
               wheelchair_boarding: 1,
               location_type: 0,
               zone_id: nil,
               municipality: "Cambridge",
               on_street: nil,
               at_street: nil,
               vehicle_type: 1
             },
             %Stop{
               id: "Back Bay-01",
               name: "Back Bay",
               description: "Back Bay - Commuter Rail - Track 1",
               latitude: 42.347283,
               longitude: -71.075312,
               platform_code: "1",
               platform_name: "Commuter Rail - Track 1",
               parent_station: "place-bbsta",
               wheelchair_boarding: 1,
               zone_id: "CR-zone-1A",
               municipality: "Boston",
               on_street: nil,
               at_street: nil,
               vehicle_type: 2
             },
             %Stop{
               id: "node-bbsta",
               name: "Generic Node",
               description: "Back Bay Generic Node",
               parent_station: "place-bbsta",
               wheelchair_boarding: 1,
               location_type: 3,
               municipality: nil,
               on_street: nil,
               at_street: nil,
               vehicle_type: nil
             }
           ]
  end

  test "parse: parses older CSV files with fewer fields" do
    body =
      ~s("stop_id","stop_code","stop_name","stop_desc","stop_lat","stop_lon","zone_id","stop_url","location_type","parent_station","wheelchair_boarding"
"Wareham Village","","Wareham Village","",41.758333,-70.714722,"","",0,"",1)

    assert Parse.Stops.parse(body) == [
             %Model.Stop{
               id: "Wareham Village",
               name: "Wareham Village",
               latitude: 41.758333,
               longitude: -70.714722,
               wheelchair_boarding: 1,
               location_type: 0
             }
           ]
  end
end
