defmodule Parse.RoutesTest do
  use ExUnit.Case, async: true

  import Parse.Routes
  alias Model.Route

  describe "parse_row/1" do
    test "parses a route CSV map into a %Route{}" do
      row = %{
        "route_id" => "CapeFlyer",
        "agency_id" => "3",
        "route_short_name" => "",
        "route_long_name" => "CapeFLYER",
        "route_desc" => "",
        "route_fare_class" => "Rapid Transit",
        "route_type" => "2",
        "route_url" => "http://capeflyer.com/",
        "route_color" => "006595",
        "route_text_color" => "FFFFFF",
        "route_sort_order" => "100",
        "line_id" => "line-Orange",
        "listed_route" => "1"
      }

      expected = %Route{
        id: "CapeFlyer",
        agency_id: "3",
        short_name: "",
        long_name: "CapeFLYER",
        description: "",
        fare_class: "Rapid Transit",
        type: 2,
        color: "006595",
        text_color: "FFFFFF",
        sort_order: 100,
        line_id: "line-Orange",
        listed_route: false,
        direction_destinations: [nil, nil],
        direction_names: [nil, nil]
      }

      assert parse_row(row) == expected
    end
  end
end
