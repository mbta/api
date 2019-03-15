defmodule Parse.TripsTest do
  use ExUnit.Case
  import Parse.Trips

  alias Model.Trip

  setup do
    blob = """
    "route_id","service_id","trip_id","trip_headsign","trip_short_name","direction_id","block_id","shape_id","wheelchair_accessible","route_pattern_id"
    "1","BUS22016-hbc26ns1-Weekday-02","30133120","Dudley","",1,"C01-12","010058",1,rpi
    """

    {:ok, %{blob: blob}}
  end

  test "parse: parses a CSV blob into a list of trips, defaulting bikes_allowed", %{blob: blob} do
    assert parse(blob) == [
             %Trip{
               id: "30133120",
               service_id: "BUS22016-hbc26ns1-Weekday-02",
               route_id: "1",
               headsign: "Dudley",
               name: "",
               direction_id: 1,
               block_id: "C01-12",
               shape_id: "010058",
               wheelchair_accessible: 1,
               bikes_allowed: 0,
               route_pattern_id: "rpi"
             }
           ]
  end

  test "parse: parses a CSV blob with bikes_allowed properly" do
    blob = """
    "route_id","service_id","trip_id","trip_headsign","trip_short_name","direction_id","block_id","shape_id","wheelchair_accessible","bikes_allowed"
    "1","BUS22016-hbc26ns1-Weekday-02","30133120","Dudley","",1,"C01-12","010058",1,1
    """

    assert parse(blob) == [
             %Trip{
               id: "30133120",
               service_id: "BUS22016-hbc26ns1-Weekday-02",
               route_id: "1",
               headsign: "Dudley",
               name: "",
               direction_id: 1,
               block_id: "C01-12",
               shape_id: "010058",
               wheelchair_accessible: 1,
               bikes_allowed: 1
             }
           ]
  end

  test "parse: bikes allowed can be the empty string" do
    blob = """
    "route_id","service_id","trip_id","trip_headsign","trip_short_name","direction_id","block_id","shape_id","wheelchair_accessible","bikes_allowed"
    "1","BUS22016-hbc26ns1-Weekday-02","30133120","Dudley","",1,"C01-12","010058",1,
    """

    [trip] = parse(blob)
    assert trip.bikes_allowed == 0
  end

  test "parse: parses trip_route_type into the route_type field" do
    blob = """
    "route_id","service_id","trip_id","trip_headsign","trip_short_name","direction_id","block_id","shape_id","wheelchair_accessible","trip_route_type"
    "1","BUS22016-hbc26ns1-Weekday-02","30133120","Dudley","",1,"C01-12","010058",1,"2"
    """

    assert [%Trip{route_type: 2}] = parse(blob)
  end
end
