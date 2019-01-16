defmodule Parse.Polyline do
  @moduledoc """
  Parses the latitude/longitude pairs from shapes.txt into a
  [polyline](https://developers.google.com/maps/documentation/utilities/polylinealgorithm)
  """
  @behaviour Parse

  defstruct [:id, :polyline]

  def parse(blob) when is_binary(blob) do
    blob
    |> ExCsv.parse!(headings: true)
    |> Enum.group_by(& &1["shape_id"])
    |> Enum.map(&parse_shape(elem(&1, 1)))
  end

  defp parse_shape([%{"shape_id" => id} | _] = points) do
    %__MODULE__{
      id: id,
      polyline: polyline(points)
    }
  end

  defp polyline(points) do
    points
    |> Enum.sort_by(&Integer.parse(&1["shape_pt_sequence"]))
    |> Enum.flat_map(fn %{"shape_pt_lat" => lat, "shape_pt_lon" => lon} ->
      with {lon, ""} <- Float.parse(lon),
           {lat, ""} <- Float.parse(lat) do
        [{lon, lat}]
      else
        _ -> []
      end
    end)
    |> Polyline.encode()
  end
end
