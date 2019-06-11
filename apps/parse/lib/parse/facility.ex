defmodule Parse.Facility do
  @moduledoc """

  Parser for elevators.csv

  """
  use Parse.Simple

  alias Model.Facility

  def parse_row(row) do
    %Facility{
      id: copy(row["facility_id"]),
      stop_id: copy(row["stop_id"]),
      long_name: optional_string(row["facility_long_name"]),
      short_name: optional_string(row["facility_short_name"]),
      type: type(row["facility_type"]),
      latitude: optional_latlng(row["facility_lat"]),
      longitude: optional_latlng(row["facility_lon"])
    }
  end

  defp optional_latlng("") do
    nil
  end

  defp optional_latlng(value) do
    String.to_float(value)
  end

  defp optional_string(""), do: nil
  defp optional_string(value), do: value

  defp type(string) do
    string
    |> String.upcase()
    |> String.replace("-", "_")
  end
end
