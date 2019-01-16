defmodule Parse.DirectionsTest do
  use ExUnit.Case, async: true

  import Parse.Directions

  describe "parse_row/1" do
    test "parses a route CSV map into a valid structure" do
      row = %{
        "route_id" => "708",
        "direction_id" => "0",
        "direction" => "Outbound",
        "direction_destination" => "Beth Israel Deaconess or Boston Medical Center"
      }

      expected = %Parse.Directions{
        route_id: "708",
        direction_id: "0",
        direction: "Outbound",
        direction_destination: "Beth Israel Deaconess or Boston Medical Center"
      }

      assert parse_row(row) == expected
    end
  end
end
