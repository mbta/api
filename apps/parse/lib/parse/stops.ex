defmodule Parse.Stops do
  @moduledoc """
  Parses `stops.txt` CSV from GTFS zip

      "stop_id","stop_code","stop_name","stop_desc","stop_lat","stop_lon","zone_id","stop_url","location_type","parent_station","wheelchair_boarding"
      "Wareham Village","","Wareham Village","",41.758333,-70.714722,"","",0,"",1

  """

  use Parse.Simple

  @doc """
  Parses (non-header) row of `stops.txt`

  See `Model.Stop.t` documentation for descriptions of the individual fields.
  """
  def parse_row(row) do
    %Model.Stop{
      id: copy(row["stop_id"]),
      name: copy(row["stop_name"]),
      description: copy_if_not_blank(row["stop_desc"]),
      address: copy_if_not_blank(row["stop_address"]),
      platform_code: copy_if_not_blank(row["platform_code"]),
      platform_name: copy_if_not_blank(row["platform_name"]),
      latitude: optional_float(Map.get(row, "stop_lat")),
      longitude: optional_float(Map.get(row, "stop_lon")),
      parent_station: copy_if_not_blank(row["parent_station"]),
      wheelchair_boarding: String.to_integer(row["wheelchair_boarding"]),
      location_type: String.to_integer(row["location_type"]),
      zone_id: copy_if_not_blank(row["zone_id"])
    }
  end

  defp copy_if_not_blank(binary) when byte_size(binary) > 0 do
    copy(binary)
  end

  defp copy_if_not_blank(_), do: nil

  defp optional_float(""), do: nil
  defp optional_float(binary) when is_binary(binary), do: String.to_float(binary)
end
