defmodule Parse.LineTest do
  use ExUnit.Case, async: true

  import Parse.Line
  alias Model.Line

  describe "parse_row/1" do
    test "parses a route CSV map into a %Line{}" do
      row = %{
        "line_id" => "line-Middleborough",
        "line_short_name" => "",
        "line_long_name" => "Middleborough/Lakeville Line",
        "line_desc" => "",
        "line_url" => "",
        "line_color" => "80276C",
        "line_text_color" => "FFFFFF",
        "line_sort_order" => "59"
      }

      expected = %Line{
        id: "line-Middleborough",
        short_name: "",
        long_name: "Middleborough/Lakeville Line",
        description: "",
        color: "80276C",
        text_color: "FFFFFF",
        sort_order: 59
      }

      assert parse_row(row) == expected
    end
  end
end
