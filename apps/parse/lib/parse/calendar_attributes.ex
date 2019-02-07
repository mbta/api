defmodule Parse.CalendarAttributes do
  @moduledoc """
  Parser for GTFS calendar_attributes.txt
  """

  use Parse.Simple

  @type t :: %__MODULE__{
          service_id: String.t(),
          description: String.t() | nil,
          schedule_name: String.t() | nil,
          schedule_type: String.t() | nil,
          schedule_typicality: integer() | nil
        }

  defstruct [
    :service_id,
    :description,
    :schedule_name,
    :schedule_type,
    :schedule_typicality
  ]

  @spec parse_row(map()) :: t
  def parse_row(row) do
    %__MODULE__{
      service_id: copy_string(row["service_id"]),
      description: copy_string(row["service_description"]),
      schedule_name: copy_string(row["service_schedule_name"]),
      schedule_type: copy_string(row["service_schedule_type"]),
      schedule_typicality: copy_int(row["service_schedule_typicality"])
    }
  end

  defp copy_string(""), do: nil
  defp copy_string(s), do: :binary.copy(s)

  defp copy_int(""), do: nil
  defp copy_int(s), do: String.to_integer(s)
end
