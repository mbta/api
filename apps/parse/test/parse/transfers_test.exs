defmodule Parse.TransfersTest do
  use ExUnit.Case, async: true
  alias Model.Transfer

  setup do
    blob = """
    from_stop_id,to_stop_id,transfer_type,min_transfer_time,min_walk_time,min_wheelchair_time,suggested_buffer_time,wheelchair_transfer
    102,1060,0,,,,,1
    place-cntsq,102,0,,,,,1
    10642,Forest Hills-02,2,188,98,154,90,1    
    """

    {:ok, %{blob: blob}}
  end

  test "parse: parses a CSV blob into a list of transfers", %{blob: blob} do
    assert Parse.Transfers.parse(blob) == [
             %Transfer{
               from_stop_id: "102",
               to_stop_id: "1060",
               transfer_type: 0,
               min_transfer_time: nil,
               min_walk_time: nil,
               min_wheelchair_time: nil,
               suggested_buffer_time: nil,
               wheelchair_transfer: 1
             },
             %Transfer{
               from_stop_id: "place-cntsq",
               to_stop_id: "102",
               transfer_type: 0,
               min_transfer_time: nil,
               min_walk_time: nil,
               min_wheelchair_time: nil,
               suggested_buffer_time: nil,
               wheelchair_transfer: 1
             },
             %Transfer{
               from_stop_id: "10642",
               to_stop_id: "Forest Hills-02",
               transfer_type: 2,
               min_transfer_time: 188,
               min_walk_time: 98,
               min_wheelchair_time: 154,
               suggested_buffer_time: 90,
               wheelchair_transfer: 1
             }
           ]
  end
end
