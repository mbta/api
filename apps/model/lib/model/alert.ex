defmodule Model.Alert do
  @moduledoc """
  An `effect` on the provided service (`informed_entity`) described by a `banner`, `header`, and `description` that is
  active for one or more periods (`active_period`) caused by a `cause`.  The alert has a `lifecycle` that can be read
  by humans in its `timeframe`.  The overall alert can be read by huamns (`service_effect`).

  See [GTFS Realtime `FeedMessage` `FeedEntity` `Alert`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)
  """

  use Recordable, [
    :id,
    :effect,
    :cause,
    :url,
    :header,
    :short_header,
    :description,
    :created_at,
    :updated_at,
    :severity,
    :service_effect,
    :timeframe,
    :lifecycle,
    :banner,
    :image,
    :image_alternative_text,
    :duration_certainty,
    active_period: [],
    informed_entity: []
  ]

  @typedoc """
  An activity affected by an alert.

  | Value                | Description                                                                                                                                                                                                                                                                       |
  |----------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
  | `"BOARD"`            | Boarding a vehicle. Any passenger trip includes boarding a vehicle and exiting from a vehicle.                                                                                                                                                                                    |
  | `"BRINGING_BIKE"`    | Bringing a bicycle while boarding or exiting.                                                                                                                                                                                                                                     |
  | `"EXIT"`             | Exiting from a vehicle (disembarking). Any passenger trip includes boarding a vehicle and exiting a vehicle.                                                                                                                                                                      |
  | `"PARK_CAR"`         | Parking a car at a garage or lot in a station.                                                                                                                                                                                                                                    |
  | `"RIDE"`             | Riding through a stop without boarding or exiting.. Not every passenger trip will include this -- a passenger may board at one stop and exit at the next stop.                                                                                                                    |
  | `"STORE_BIKE"`       | Storing a bicycle at a station.                                                                                                                                                                                                                                                   |
  | `"USING_ESCALATOR"`  | Using an escalator while boarding or exiting (should only be used for customers who specifically want to avoid stairs.)                                                                                                                                                           |
  | `"USING_WHEELCHAIR"` | Using a wheelchair while boarding or exiting. Note that this applies to something that specifically affects customers who use a wheelchair to board or exit; a delay should not include this as an affected activity unless it specifically affects customers using wheelchairs.  |
  """
  @type activity :: String.t()

  # \ is included at end of lines still in the same paragraph, so that formatting is correct in both earmark for ex_doc
  # AND CommonMark for Swagger
  @typedoc """
  Activities affected by this alert.

  If an entity is a station platform, and the alert only impacts those boarding at that platform and no one else, and \
  the activity `"BOARD"` represents customers boarding at the informed entity, then the entity includes `activities` \
  `["BOARD"]`. If the alert affected customers exiting at the platform too, then `activities` is `["BOARD", "EXIT"]`.

  It should be noted that the `activities` array includes activities that are specifically affected. Thus if there \
  were activities `"BOARD"`, `"EXIT"`, and `"USING_WHEELCHAIR"` [to board or exit], and a station were closed, then \
  the `activities` array would include `"BOARD"` and `"EXIT"` but it would not be necessary to include the activity \
  `"USING_WHEELCHAIR"`. Any rider entering the station who is `"USING_WHEELCHAIR"` is also a rider who `"BOARD"`s. \
  Using a wheelchair to board is not specifically affected.
  """
  @type activities :: [activity]

  @typedoc """
  An entity affected by an alert. At least one of the fields other than `activities` will be \
  non-null. The affected entity is the intersection of these fields, not the union: if `stop` \
  and `route` both have values, the alert does not affect the entire route.

  See [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `EntitySelector`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-entityselector).

  * `activities` - The activities affected.
  * `direction_id` - The direction of the affected `trip`. See \
      [GTFS `trips.txt` `direction_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt).
  * `facility` - The facility affected.
  * `route` - The route affected. See \
      [GTFS `routes.txt` `route_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt)
  * `route_type` - The type of route affected. If present alone, indicates the entire mode of transit is affected. See \
      [GTFS `routes.txt` `route_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt)
  * `stop` - The stop affected. See \
      [GTFS `stops.txt` `stop_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt)
  * `trip` - The trip affected. See \
      [GTFS `trips.txt` `trip_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt)
  """
  @type informed_entity :: %{
          optional(:activities) => activities,
          optional(:direction_id) => Model.Direction.id(),
          optional(:facility) => Model.Facility.id(),
          optional(:route) => Model.Route.id(),
          optional(:route_type) => Model.Route.route_type(),
          optional(:stop) => Model.Stop.id(),
          optional(:trip) => Model.Trip.id()
        }

  @cause_enum ~w(
    ACCIDENT
    AMTRAK_TRAIN_TRAFFIC
    COAST_GUARD_RESTRICTION
    CONSTRUCTION
    CROSSING_ISSUE
    DEMONSTRATION
    DISABLED_BUS
    DISABLED_TRAIN
    DRAWBRIDGE_BEING_RAISED
    ELECTRICAL_WORK
    FIRE
    FIRE_DEPARTMENT_ACTIVITY
    FLOODING
    FOG
    FREIGHT_TRAIN_INTERFERENCE
    HAZMAT_CONDITION
    HEAVY_RIDERSHIP
    HIGH_WINDS
    HOLIDAY
    HURRICANE
    ICE_IN_HARBOR
    MAINTENANCE
    MECHANICAL_ISSUE
    MECHANICAL_PROBLEM
    MEDICAL_EMERGENCY
    PARADE
    POLICE_ACTION
    POLICE_ACTIVITY
    POWER_PROBLEM
    RAIL_DEFECT
    SEVERE_WEATHER
    SIGNAL_ISSUE
    SIGNAL_PROBLEM
    SINGLE_TRACKING
    SLIPPERY_RAIL
    SNOW
    SPECIAL_EVENT
    SPEED_RESTRICTION
    SWITCH_ISSUE
    SWITCH_PROBLEM
    TIE_REPLACEMENT
    TRACK_PROBLEM
    TRACK_WORK
    TRAFFIC
    TRAIN_TRAFFIC
    UNKNOWN_CAUSE
    UNRULY_PASSENGER
    WEATHER
  )

  @typedoc """
  | Value |
  |-------|
  #{Enum.map_join(@cause_enum, "\n", &"| `\"#{&1}\"` |")}

  See [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `Cause`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-cause)
  """
  @type cause :: String.t()

  @typedoc """
  Time when the alert should be shown to the user. If missing, the alert will be shown as long as it appears in the
  feed. If multiple ranges are given, the alert will be shown during all of them.

  * `{DateTime.t, DateTime.t}` - a bound interval
  * `{DateTime.t, nil}` - an interval that started in the past and has not ended yet and is not planned to end anytime
  * `{nil, DateTime.t}` an interval that has existed for all time until the end time.

  See [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `TimeRange`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-timerange)
  """
  @type datetime_pair :: {DateTime.t(), DateTime.t()} | {DateTime.t(), nil} | {nil, DateTime.t()}

  @effect_enum ~w(
    ACCESS_ISSUE
    ADDITIONAL_SERVICE
    AMBER_ALERT
    BIKE_ISSUE
    CANCELLATION
    DELAY
    DETOUR
    DOCK_CLOSURE
    DOCK_ISSUE
    ELEVATOR_CLOSURE
    ESCALATOR_CLOSURE
    EXTRA_SERVICE
    FACILITY_ISSUE
    MODIFIED_SERVICE
    NO_SERVICE
    OTHER_EFFECT
    PARKING_CLOSURE
    PARKING_ISSUE
    POLICY_CHANGE
    SCHEDULE_CHANGE
    SERVICE_CHANGE
    SHUTTLE
    SNOW_ROUTE
    STATION_CLOSURE
    STATION_ISSUE
    STOP_CLOSURE
    STOP_MOVE
    STOP_MOVED
    SUMMARY
    SUSPENSION
    TRACK_CHANGE
    UNKNOWN_EFFECT
  )

  @typedoc """
  | Value |
  |-------|
  #{Enum.map_join(@effect_enum, "\n", &"| `\"#{&1}\"` |")}

  See [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `effect`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)
  """
  @type effect :: String.t()

  @type id :: String.t()

  @typedoc """
  Identifies whether alert is a new or old, in effect or upcoming.

  | Value                |
  |----------------------|
  | `"NEW"`              |
  | `"ONGOING"`          |
  | `"ONGOING_UPCOMING"` |
  | `"UPCOMING"`         |

  """
  @type lifecycle :: String.t()

  @typedoc """
  How severe the alert is from least (`0`) to most (`10`) severe.
  """
  @type severity :: 0..10

  @duration_certainty_enum ~w(
    UNKNOWN
    KNOWN
    ESTIMATED
  )

  @typedoc """
  | Value |
  |-------|
  #{Enum.map_join(@duration_certainty_enum, "\n", &"| `\"#{&1}\"` |")}
  Indicates whether an alert has a KNOWN, ESTIMATED, or UNKNOWN duration. KNOWN duration_certainty alerts are expected \
  to end at the specified end time, ESTIMATED duration_certainty alerts have an estimated end time, and \
  UNKNOWN duration_certainty alerts do not have a known or estimated end time.
  """
  @type duration_certainty :: String.t()

  @typedoc """
  * `:id` - Unique ID
  * `:active_period` - See `t:datetime_pair/0` for individual entries in list.
  * `:banner` - Set if alert is meant to be displayed prominently, such as the top of every page.
  * `:cause` - Cause of the alert.  See `t:cause/0` for all names and values.
  * `:create` - When the alert was created, which is completely unrelarted to the `active_period`s.
  * `:description` - This plain-text string will be formatted as the body of the alert (or shown on an explicit
      "expand" request by the user). The information in the description should add to the information of the header. See
      [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `description_text`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)
  * `:effect` - The effect of this problem on the affected entity. See
      [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `effect`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)
  * `:header` - This plain-text string will be highlighted, for example in boldface. See
      [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `header_text`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)
  * `:image` - A link to an image to be displayed along with the alert text. See
      [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `image`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)
  * `:image_alternative_text` - Text to be displayed along with the image. See
      [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `image_alternative_text`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)
  * `:informed_entity` - Entities whose users we should notify of this alert.  See
      [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `informed_entity`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)
  * `:lifecycle` - Enumeration of where the alert is in its lifecycle.  See `t:lifecycle/0`.
  * `:service_effect` - Summarizes the service and the impact to that service.
  * `:severity` - Servity of the alert.  See `t:severity/0`.
  * `:short_header` - A shortened version of `:header`.
  * `:duration_certainty` - Indicates whether an alert has a KNOWN, ESTIMATED, or UNKNOWN duration. KNOWN duration_certainty alerts are expected \
      to end at the specified end time, ESTIMATED duration_certainty alerts have an estimated end time, and \
      UNKNOWN duration_certainty alerts do not have a known or estimated end time.
  * `:timeframe` - Summarizes when an alert is in effect.
  * `:updated_at` - The last time this alert was updated.
  * `:url` - A URL for extra details, such as outline construction or maintenance plans.
  """
  @type t :: %__MODULE__{
          id: id,
          active_period: [datetime_pair],
          banner: String.t() | nil,
          cause: cause,
          created_at: DateTime.t(),
          description: String.t(),
          effect: effect,
          header: String.t(),
          image: String.t() | nil,
          image_alternative_text: String.t() | nil,
          informed_entity: [informed_entity],
          lifecycle: lifecycle,
          service_effect: String.t(),
          severity: severity,
          short_header: String.t(),
          duration_certainty: String.t(),
          timeframe: String.t(),
          updated_at: DateTime.t(),
          url: String.t()
        }

  @doc false
  def cause_enum, do: @cause_enum

  @doc false
  def effect_enum, do: @effect_enum

  @doc false
  def duration_certainty_enum, do: @duration_certainty_enum
end
