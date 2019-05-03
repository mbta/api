defmodule Model.Stop do
  @moduledoc """
  Stop represents a physical location where the transit system can pick up or drop off passengers.  See
  [GTFS `stops.txt`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt)
  """

  use Recordable, [
    :id,
    :name,
    :description,
    :address,
    :platform_code,
    :platform_name,
    :latitude,
    :longitude,
    :parent_station,
    :zone_id,
    wheelchair_boarding: 0,
    location_type: 0
  ]

  alias Model.WGS84

  @type id :: String.t()
  @typedoc """
  The meaning of `wheelchair_boarding` varies based on whether this is a stop or station.

  ## Indepent Stop or Parent Station

  | Value | Vehicles with wheelchair boarding | Meaning |
  |-------|-----------------------------------|---------|
  | `0`   | N/A                               | No accessibility information is available |
  | `1`   | >= 1                              | At least some vehicles at this stop can be boarded by a rider in a wheelchair |
  | `2`   | 0                                 | Wheelchair boarding is not possible at this stop |

  ## Stop/Platform at a Parent Station

  | Value | Wheelchair accessible paths | Meaning |
  |-------|-----------------------------|---------|
  | `0`   | Inherit                     | Inherit from parent station |
  | `1`   | 1                           | There exists some accessible path from outside the station to the specific stop |
  | `2`   | 0                           | There exists no accessible path from outside the station to the specific stop / platform |

  See [GTFS `stops.txt` `wheelchair_boarding`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
  """
  @type wheelchair_boarding :: 0..2

  @typedoc """
  | Value | Type | Description |
  | - | - | - |
  | `0` | Stop | A location where passengers board or disembark from a transit vehicle. |
  | `1` | Station | A physical structure or area that contains one or more stops. |
  | `2` | Station Entrance/Exit | A location where passengers can enter or exit a station from the street. The stop entry must also specify a parent_station value referencing the stop ID of the parent station for the entrance. |
  """
  @type location_type :: 0..2

  @typedoc """
  * `:id` - the unique ID for this stop. See [GTFS `stops.txt` `stop_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
  * `:name` - Name of a stop, station, or station entrance in the local and tourist vernacular.  See [GTFS `stops.txt` `stop_name`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt)
  * `:description` - Description of the stop. See [GTFS `stops.txt` `stop_desc`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
  * `:address` - A street address for the station. See [MBTA extensions to GTFS](https://docs.google.com/document/d/1RoQQj3_-7FkUlzFP4RcK1GzqyHp4An2lTFtcmW0wrqw/view).
  * `:platform_code` - A short code representing the platform/track (like a number or letter). See [GTFS `stops.txt` `platform_code`](https://developers.google.com/transit/gtfs/reference/gtfs-extensions#stopstxt_1).
  * `:platform_name` - A textual description of the platform or track. See [MBTA extensions to GTFS](https://docs.google.com/document/d/1RoQQj3_-7FkUlzFP4RcK1GzqyHp4An2lTFtcmW0wrqw/view).
  * `:latitude` - Latitude of the stop or station.  See
      [GTFS `stops.txt` `stop_lat`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
  * `:longitude` - Longitude of the stop or station. See
      [GTFS `stops.txt` `stop_lon`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
  * `:parent_station` - `id` of the `Model.Stop.t` representing the station this stop is inside or outside.  `nil` if
      this is a station or a stop not associated with a station.
  * `:wheelchair_boarding` - See [GTFS `stops.txt` `wheelchair_boarding`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
  * `:location_type` - See [GTFS `stops.txt` `location_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
  """
  @type t :: %__MODULE__{
          id: id,
          name: String.t(),
          description: String.t() | nil,
          address: String.t() | nil,
          platform_code: String.t() | nil,
          platform_name: String.t() | nil,
          latitude: WGS84.latitude(),
          longitude: WGS84.longitude(),
          parent_station: id | nil,
          wheelchair_boarding: wheelchair_boarding,
          location_type: location_type,
          zone_id: String.t() | nil
        }

  @doc """
  Returns a boolean indicating whether the stop has a location.

  ## Examples
  iex> located?(%Stop{latitude: 1, longitude: -2})
  true

  iex> located?(%Stop{})
  false
  """
  def located?(%__MODULE__{} = stop) do
    case stop do
      %{latitude: lat, longitude: lon} when is_number(lat) and is_number(lon) ->
        true

      _ ->
        false
    end
  end
end
