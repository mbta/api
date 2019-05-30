defmodule Model.Facility do
  @moduledoc """
  Station amenities such as elevators, escalators, parking lots and bike storage.
  """

  use Recordable, [
    :id,
    :stop_id,
    :type,
    :name,
    :long_name,
    :short_name,
    :latitude,
    :longitude
  ]

  alias Model.WGS84

  @type id :: String.t()

  @typedoc """
  * `:id` -  Unique ID
  * `:name` - (obsolete, renamed to `long_name`) Descriptive name of facility which can be used without any additional context.
  * `:long_name` - Descriptive name of facility which can be used without any additional context.
  * `:short_name` - Short name of facility which might not include its station or type.
  * `:stop_id` - The `Model.Stop.id` of the station where facility is.
  * `:type` - What kind of amenity the facility is.
  * `:latitude` - Latitude of the facility
  * `:longitude` - Longitude of the facility
  """
  @type t :: %__MODULE__{
          id: id,
          name: String.t() | nil,
          long_name: String.t() | nil,
          short_name: String.t() | nil,
          stop_id: Model.Stop.id(),
          type: String.t(),
          latitude: WGS84.latitude() | nil,
          longitude: WGS84.longitude() | nil
        }
end
