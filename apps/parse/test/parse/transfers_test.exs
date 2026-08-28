defmodule Parse.TransfersTest do
  use ExUnit.Case, async: true
  alias Model.Transfer

  @header "from_stop_id,to_stop_id,transfer_type,min_transfer_time,min_walk_time,min_wheelchair_time,suggested_buffer_time,wheelchair_transfer,from_trip_id,to_trip_id\n"

  describe "parse_row/1" do
    test "parses a fully-populated row" do
      row = %{
        "from_stop_id" => "place-north",
        "to_stop_id" => "place-south",
        "transfer_type" => "2",
        "min_transfer_time" => "360",
        "min_walk_time" => "300",
        "min_wheelchair_time" => "420",
        "suggested_buffer_time" => "60",
        "wheelchair_transfer" => "1",
        "from_trip_id" => "trip-A",
        "to_trip_id" => "trip-B"
      }

      assert Parse.Transfers.parse_row(row) == %Transfer{
               from_stop_id: "place-north",
               to_stop_id: "place-south",
               transfer_type: 2,
               min_transfer_time: 360,
               min_walk_time: 300,
               min_wheelchair_time: 420,
               suggested_buffer_time: 60,
               wheelchair_transfer: 1,
               from_trip_id: "trip-A",
               to_trip_id: "trip-B"
             }
    end

    test "parses a row with blank optional fields as nil or 0" do
      row = %{
        "from_stop_id" => "FR-0301-02",
        "to_stop_id" => "FR-0301-01",
        "transfer_type" => "0",
        "min_transfer_time" => "",
        "min_walk_time" => "",
        "min_wheelchair_time" => "",
        "suggested_buffer_time" => "",
        "wheelchair_transfer" => "",
        "from_trip_id" => "NorthBase-825665-1427",
        "to_trip_id" => "NorthBase-825779-429"
      }

      assert Parse.Transfers.parse_row(row) == %Transfer{
               from_stop_id: "FR-0301-02",
               to_stop_id: "FR-0301-01",
               transfer_type: 0,
               min_transfer_time: nil,
               min_walk_time: nil,
               min_wheelchair_time: nil,
               suggested_buffer_time: nil,
               wheelchair_transfer: 0,
               from_trip_id: "NorthBase-825665-1427",
               to_trip_id: "NorthBase-825779-429"
             }
    end

    test "parses a row with blank trip IDs as nil" do
      row = %{
        "from_stop_id" => "stop-A",
        "to_stop_id" => "stop-B",
        "transfer_type" => "3",
        "min_transfer_time" => "",
        "min_walk_time" => "",
        "min_wheelchair_time" => "",
        "suggested_buffer_time" => "",
        "wheelchair_transfer" => "0",
        "from_trip_id" => "",
        "to_trip_id" => ""
      }

      result = Parse.Transfers.parse_row(row)
      assert result.from_trip_id == nil
      assert result.to_trip_id == nil
    end
  end

  describe "parse/1" do
    test "parses a CSV blob with a header into a list of transfers" do
      blob =
        @header <>
          "FR-0301-02,FR-0301-01,0,,,,,,NorthBase-825665-1427,NorthBase-825779-429\n"

      [transfer] = Parse.Transfers.parse(blob)
      assert transfer.from_stop_id == "FR-0301-02"
      assert transfer.to_stop_id == "FR-0301-01"
      assert transfer.transfer_type == 0
      assert transfer.from_trip_id == "NorthBase-825665-1427"
    end

    test "parses multiple rows" do
      blob =
        @header <>
          "stop-A,stop-B,1,120,60,90,60,1,,\n" <>
          "stop-C,stop-D,2,300,240,360,60,0,,\n"

      transfers = Parse.Transfers.parse(blob)
      assert length(transfers) == 2
      assert Enum.map(transfers, & &1.from_stop_id) == ["stop-A", "stop-C"]
    end
  end
end
