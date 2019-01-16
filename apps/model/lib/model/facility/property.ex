defmodule Model.Facility.Property do
  @moduledoc """
  A property of a facility. The names are not unique, even within a facility_id.
  """

  use Recordable, [
    :facility_id,
    :name,
    :value,
    :updated_at
  ]

  @typedoc """
  * `:name` -  Name of the property
  * `:facility_id` - The `Model.Facility.id` this property applies to.
  * `:value` - Value of the property
  """
  @type t :: %__MODULE__{
          name: String.t(),
          facility_id: Model.Facility.id(),
          value: term,
          updated_at: DateTime.t() | nil
        }
end
