defmodule Parse.Facility.Property do
  @moduledoc """

  Parser for facility_properties.txt

  """
  use Parse.Simple

  alias Model.Facility.Property

  def parse_row(row) do
    %Property{
      name: copy(row["property_id"]),
      facility_id: copy(row["facility_id"]),
      value: decode_value(row["value"])
    }
  end

  defp decode_value(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> value
    end
  end
end
