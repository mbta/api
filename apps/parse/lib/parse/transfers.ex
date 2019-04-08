defmodule Parse.Transfers do
  @moduledoc """
  Parses `transfers.txt` CSV from GTFS zip

      "from_stop_id","to_stop_id","transfer_type","min_transfer_time","min_walk_time","min_wheelchair_time","suggested_buffer_time","wheelchair_transfer"
      "place-cntsq","1123","0","","","","","1"

  """

  use Parse.Simple

  @doc """
  Parses (non-header) row of `transfers.txt`

  See `Model.Transfer.t` documentation for descriptions of the individual fields.
  """
  def parse_row(row) do
    %Model.Transfer{
      from_stop_id: copy(row["from_stop_id"]),
      to_stop_id: copy(row["to_stop_id"]),
      transfer_type: String.to_integer(row["transfer_type"]),
      min_transfer_time: to_integer_if_not_blank(row["min_transfer_time"]),
      min_walk_time: to_integer_if_not_blank(row["min_walk_time"]),
      min_wheelchair_time: to_integer_if_not_blank(row["min_wheelchair_time"]),
      suggested_buffer_time: to_integer_if_not_blank(row["suggested_buffer_time"]),
      wheelchair_transfer: to_integer_if_not_blank(row["wheelchair_transfer"])
    }
  end

  defp to_integer_if_not_blank(binary) when byte_size(binary) > 0 do
    String.to_integer(binary)
  end

  defp to_integer_if_not_blank(_) do
    nil
  end
end
