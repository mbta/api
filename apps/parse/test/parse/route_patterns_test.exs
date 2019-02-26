defmodule Parse.RoutePatternsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  describe "parse/1" do
    test "parses a CSV blob into a list of %RoutePattern{} structs" do
      blob = ~s(
route_pattern_id,route_id,direction_id,route_pattern_name,route_pattern_time_desc,route_pattern_typicality,route_pattern_sort_order,representative_trip_id
Red-1-0,Red,0,Ashmont,,1,10010051,38899721-21:00-KL
)

      assert Parse.RoutePatterns.parse(blob) == [
               %Model.RoutePattern{
                 id: "Red-1-0",
                 route_id: "Red",
                 direction_id: 0,
                 name: "Ashmont",
                 time_desc: nil,
                 typicality: 1,
                 sort_order: 10_010_051,
                 representative_trip_id: "38899721-21:00-KL"
               }
             ]
    end
  end
end
