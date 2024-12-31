defmodule Parse.AgencyTest do
  use ExUnit.Case, async: true

  import Parse.Agency
  alias Model.Agency

  describe "parse_row/1" do
    test "parses a route CSV map into an %Agency{}" do
      row = %{
        "agency_id" => "1",
        "agency_name" => "MBTA",
        "agency_url" => "http://www.mbta.com",
        "agency_timezone" => "America/New_York",
        "agency_lang" => "EN",
        "agency_phone" => "617-222-3200"
      }

      expected = %Agency{
        id: "1",
        agency_name: "MBTA"
      }

      assert parse_row(row) == expected
    end
  end
end
