defmodule Parse.Transfers do
  @moduledoc """
  Parses `transfers.txt` CSV from GTFS zip

    from_stop_id,to_stop_id,transfer_type,min_transfer_time,min_walk_time,min_wheelchair_time,suggested_buffer_time,wheelchair_transfer,from_trip_id,to_trip_id
    FR-0301-02,FR-0301-01,0,,,,,,NorthBase-825665-1427,NorthBase-825779-429
  """

  use Parse.Simple
  alias Model.Transfer

  @doc """
  Parses (non-header) row of `transfers.txt`

  ## Columns

  * `"from_stop_id"` - `Model.Stop.id | nil`
  * `"to_stop_id"` - `Model.Stop.id | nil`
  * `"transfer_type"` - `Model.Transfer.transfer_type`
  * `"min_transfer_time"` - `Model.Transfer.min_transfer_time` | nil
  * `"min_walk_time"` - `Model.Transfer.t` - `min_walk_time` | nil
  * `"min_wheelchair_time"` - `Model.Transfer.t` - `min_wheelchair_time`
  * `"suggested_buffer_time"` - `Model.Transfer.t` - `suggested_buffer_time`
  * `"wheelchair_transfer"` - `Model.Transfer.wheelchair_transfer_type`
  * `"from_trip_id"` - `Model.Trip.id | nil`
  * `"to_trip_id"` - `Model.Trip.id | nil`
  """
  def parse_row(row) do
    %Transfer{
      from_stop_id: copy(row["from_stop_id"]),
      to_stop_id: copy(row["to_stop_id"]),
      min_transfer_time: to_integer_if_not_blank(row["min_transfer_time"]),
      min_walk_time: to_integer_if_not_blank(row["min_walk_time"]),
      min_wheelchair_time: to_integer_if_not_blank(row["min_wheelchair_time"]),
      suggested_buffer_time: to_integer_if_not_blank(row["suggested_buffer_time"]),
      wheelchair_transfer: to_integer(row["wheelchair_transfer"]),
      from_trip_id: copy_if_not_blank(row["from_trip_id"]),
      to_trip_id: copy_if_not_blank(row["to_trip_id"]),
      transfer_type: String.to_integer(row["transfer_type"])
    }
  end

  defp to_integer(binary) when byte_size(binary) > 0 do
    String.to_integer(binary)
  end

  defp to_integer(_), do: 0

  defp to_integer_if_not_blank(binary) when byte_size(binary) > 0 do
    String.to_integer(binary)
  end

  defp to_integer_if_not_blank(_), do: nil

  defp copy_if_not_blank(binary) when byte_size(binary) > 0 do
    copy(binary)
  end

  defp copy_if_not_blank(_), do: nil
end
