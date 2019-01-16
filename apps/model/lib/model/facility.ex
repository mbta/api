defmodule Model.Facility do
  @moduledoc """
  An escalator or elevator: a way for a rider to get from one level of a station to another.
  """

  use Recordable, [
    :id,
    :stop_id,
    :type,
    :name,
    :latitude,
    :longitude
  ]

  alias Model.WGS84

  @type id :: String.t()

  @typedoc """
  * `:id` -  Unique ID
  * `:name` - Name of elevator or escalator that includes the parts of the station being connected by the facility.
  * `:stop_id` - The `Model.Stop.id` of the station where facility is.
  * `:type` - Whether this is an elevator or escalator.
  * `:latitude` - Latitude of the facility
  * `:longitude` - Longitude of the facility
  """
  @type t :: %__MODULE__{
          id: id,
          name: String.t(),
          stop_id: Model.Stop.id(),
          type: String.t(),
          latitude: WGS84.latitude() | nil,
          longitude: WGS84.longitude() | nil
        }
end
