defmodule Parse.Variant do
  @moduledoc "Parser for the shaperoutevariants.csv file"
  @behaviour Parse

  defstruct [:id, :name, primary?: false, replaced?: false]

  import :binary, only: [copy: 1]

  def parse(blob, trip_route_direction \\ "") do
    replaced = parse_trip_route_direction(trip_route_direction)

    blob
    |> ExCsv.parse!(headings: true)
    |> Enum.group_by(&{&1["route_id"], &1["trp_direction"]})
    |> Enum.flat_map(fn {{route_id, _direction}, rows} ->
      parse_route_group(rows, MapSet.member?(replaced, route_id))
    end)
  end

  defp parse_route_group(rows, replaced?) do
    # sort the primary variant first
    rows
    |> Enum.sort(&variant_id_sort(&1["via_variant"], &2["via_variant"]))
    |> Enum.map(&parse_row(&1, replaced?))
  end

  defp parse_trip_route_direction("") do
    MapSet.new()
  end

  defp parse_trip_route_direction(blob) do
    blob
    |> ExCsv.parse!(headings: true)
    |> Enum.filter(&(&1["replace_route_id"] == "1"))
    |> MapSet.new(& &1["old_route_id_short"])
  end

  def parse_row(row, replaced?) do
    %__MODULE__{
      id: copy(row["shape_id"]),
      name: copy(row["trip_headsign"]),
      primary?: primary?(row["via_variant"]),
      replaced?: replaced?
    }
  end

  defp variant_id_sort("_" <> _rest, _) do
    true
  end

  defp variant_id_sort(_, "_" <> _rest) do
    false
  end

  defp variant_id_sort(first, second) do
    first <= second
  end

  defp primary?("_" <> _), do: true
  defp primary?(_), do: false
end
