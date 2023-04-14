defmodule Parse.RoutePatterns do
  @moduledoc false
  use Parse.Simple

  @spec parse_row(%{optional(String.t()) => term()}) :: Model.RoutePattern.t()
  def parse_row(row) do
    %Model.RoutePattern{
      id: copy_string(row["route_pattern_id"]),
      route_id: copy_string(row["route_id"]),
      direction_id: copy_int(row["direction_id"]),
      name: copy_string(row["route_pattern_name"]),
      time_desc: copy_string(row["route_pattern_time_desc"]),
      typicality: copy_int(row["route_pattern_typicality"]),
      sort_order: copy_int(row["route_pattern_sort_order"]),
      representative_trip_id: copy_string(row["representative_trip_id"]),
      canonical: parse_canonical(row["canonical_route_pattern"])
    }
  end

  defp copy_string(""), do: nil
  defp copy_string(s), do: :binary.copy(s)

  defp copy_int(""), do: nil
  defp copy_int(s), do: String.to_integer(s)

  defp parse_canonical("1"), do: true
  defp parse_canonical(_), do: false
end
