defmodule Parse.StopTimesTest do
  use ExUnit.Case
  import Parse.StopTimes
  alias Model.{Schedule, Trip}

  setup do
    blob = """
    "trip_id","arrival_time","departure_time","stop_id","stop_sequence","stop_headsign","pickup_type","drop_off_type","timepoint"
    "29063613","14:36:00","14:36:01","2300","6","","0","0","1"\r
    "29063613","14:37:00","14:37:01","12301","7","","0","0","0"
    """

    {:ok, %{blob: blob}}
  end

  test "parse: parses a CSV blob into a list of stops, tagging the first stop", %{blob: blob} do
    assert blob |> parse |> Enum.sort() == [
             %Schedule{
               trip_id: "29063613",
               stop_id: "2300",
               arrival_time: 52_560,
               departure_time: 52_561,
               position: :first,
               stop_sequence: 6,
               pickup_type: 0,
               drop_off_type: 0,
               timepoint?: true
             },
             %Schedule{
               trip_id: "29063613",
               stop_id: "12301",
               arrival_time: 52_620,
               departure_time: 52_621,
               position: :last,
               stop_sequence: 7,
               pickup_type: 0,
               drop_off_type: 0,
               timepoint?: false
             }
           ]
  end

  test "removes departure/arrival times for pickup/drop-off type 1" do
    blob = """
    "trip_id","arrival_time","departure_time","stop_id","stop_sequence","stop_headsign","pickup_type","drop_off_type","timepoint"
    "29063613","14:36:00","14:36:01","2300","6","","1","1","1"\r
    """

    assert blob |> parse |> Enum.to_list() == [
             %Schedule{
               trip_id: "29063613",
               stop_id: "2300",
               arrival_time: nil,
               departure_time: nil,
               position: :last,
               stop_sequence: 6,
               pickup_type: 1,
               drop_off_type: 1,
               timepoint?: true
             }
           ]
  end

  test "if given a fn which returns a trip, only returns schedules which match and includes the route_id",
       %{blob: blob} do
    all_schedules = blob |> parse |> Enum.sort()

    assert blob |> parse(fn "29063613" -> %Trip{route_id: "route"} end) |> Enum.sort() ==
             all_schedules |> Enum.map(&%{&1 | route_id: "route"})

    assert [] == blob |> parse(fn _ -> nil end) |> Enum.into([])
  end
end
