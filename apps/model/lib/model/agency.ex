defmodule Model.Agency do
  @moduledoc """
  Agency represents a branded agency operating transit services.
  """

  use Recordable, [
    :id,
    :agency_name
  ]

  @type id :: String.t()

  @typedoc """
  * `:id` - Unique ID
  * `:agency_name` - Full name of the agency. See
    [GTFS `agency.txt` `agency_name`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#agencytxt)
  """
  @type t :: %__MODULE__{
          id: id,
          agency_name: String.t()
        }
end
