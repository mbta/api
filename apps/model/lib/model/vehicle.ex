defmodule Model.Vehicle do
  @moduledoc """
  Vehicle represents the current status of a vehicle.
  """

  use Recordable, [
    :id,
    :trip_id,
    :stop_id,
    :route_id,
    :direction_id,
    :label,
    :latitude,
    :longitude,
    :bearing,
    :speed,
    :current_status,
    :current_stop_sequence,
    :updated_at,
    :effective_route_id,
    :consist,
    :occupancy_status,
    :carriages
  ]

  alias Model.WGS84

  @typedoc """
  Unique ID for vehicle.
  """
  @type id :: String.t()

  @typedoc """
  Status of vehicle relative to the stops.

  | _**Value**_      | _**Description**_                                                                                          |
  |------------------|------------------------------------------------------------------------------------------------------------|
  | `:in_transit_to` | The vehicle has departed the previous stop and is in transit.                                              |
  | `:incoming_at`   | The vehicle is just about to arrive at the stop (on a stop display, the vehicle symbol typically flashes). |
  | `:stopped_at`    | The vehicle is standing at the stop.                                                                       |

  """
  @type current_status :: :in_transit_to | :incoming_at | :stopped_at

  @type occupancy_status ::
          :empty
          | :many_seats_available
          | :few_seats_available
          | :standing_room_only
          | :crushed_standing_room_only
          | :full
          | :not_accepting_passengers

  @typedoc """
  Meters per second
  """
  @type speed :: float

  @typedoc """
  The current status of vehicle (bus, ferry, or train)

  * `:id` - unique ID for vehicle.  See [GTFS-realtime VehicleDescriptor id](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-vehicledescriptor).
  * `:bearing` - in degrees, clockwise from True North, i.e., 0 is North and 90 is East. This can be the compass
       bearing, or the direction towards the next stop or intermediate location. See
       [GTFS-realtime Position bearing](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-position).
  * `:current_status` - Status of vehicle relative to the stops. See
       [GTFS-realtime VehicleStopStatus](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-vehiclestopstatus).
  * `:current_stop_sequence` - Index of current stop along trip. See
      [GTFS-realtime VehiclePosition current_stop_sequence](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-vehicleposition)
  * `:direction_id` - Direction of travel of the vehicle
  * `:effective_route_id` - The `Model.Route.id` of the `Model.Route.t` that the vehicle is _currently_ on.  When
      `trip_id` has only one route, then `effective_route_id` and `route_id` will always match.  If `trip_id` has
      multiple routes, then `effective_route_id` can be any of the routes of `trip_id`.
  * `:label` - User visible label, such as the one on the signage on the vehicle.  See
      [GTFS-realtime VehicleDescriptor label](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-vehicledescriptor).
  * `:consist` - Set of user visible labels (such as the one on the signage on the vehicle) on individual cars. Only present for light and heavy rail.
  * `:updated_at` - Time at which vehicle information was last updated.
  * `:latitude` - Latitude of the vehicle's current position.  See
      [GTFS-realtime Position latitude](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-position).
  * `:longitude` - Longitude of the vehicle's current position.  See
      [GTFS-realtime Position longitude](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-position).",
  * `:route_id` - The `Model.Route.id` of the primary `Model.Route.t` that the vehicle is on.  When `trip_id` has only
      one route, then `effective_route_id` and `route_id` will always match.  If `trip_id` has multiple routes, then
      `effective_route_id` can be any of the routes of `trip_id`.
  * `:speed` - Speed that the vehicle is traveling. See
      [GTFS-realtime Position speed](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-position).
  * `:stop_id` - The `Model.Stop.id` of the `Model.Stop.t` that the vehicle is `:current_status` relative to.
  * `:trip_id` - The `Model.Trip.id` of the `Model.Trip.t` that the vehicle is on.
  * `:carriages` - A list of `Model.Vehicle.Carriage` that provide occupancy on a more granular basis
  """
  @type t :: %__MODULE__{
          id: id | nil,
          bearing: non_neg_integer | nil,
          current_status: current_status,
          current_stop_sequence: non_neg_integer | nil,
          direction_id: Model.Direction.id() | nil,
          effective_route_id: Model.Route.id() | nil,
          label: String.t() | nil,
          updated_at: DateTime.t(),
          latitude: WGS84.latitude() | nil,
          longitude: WGS84.longitude() | nil,
          route_id: Model.Route.id() | nil,
          speed: speed | nil,
          stop_id: Model.Stop.id() | nil,
          trip_id: Model.Trip.id() | nil,
          consist: [String.t()] | nil,
          occupancy_status: occupancy_status() | nil,
          carriages: [Model.Vehicle.Carriage] | []
        }

  def primary?(%__MODULE__{route_id: id, effective_route_id: id}), do: true
  def primary?(%__MODULE__{}), do: false
end
