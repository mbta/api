defmodule Model.Feed do
  @moduledoc """
  Metadata about the current GTFS file.
  """

  defstruct [:name, :start_date, :end_date, :version]

  @type t :: %__MODULE__{
          name: String.t(),
          start_date: Date.t(),
          end_date: Date.t(),
          version: String.t()
        }
end
