# API Endpoints

The API (other than the health check) follows the JSON-API standard: http://jsonapi.org/

To include additional fields, you can pass `?include=<field>`

To limit the returned fields, you can pass: `?fields[<type>]=<field>,<field>`

## Alerts

Attributes:

* `header`
* `short_header`
* `description`
* `effect`
* `cause`
* `severity`
* `created_at`
* `updated_at`
* `active_period` (list)
* `informed_entity` (list)
* `service_effect`
* `timeframe`
* `lifecycle`

Available includes:

* `stops`
* `routes`
* `trips`
* `facilities`

### GET /alerts/

Returns a list of current alerts.  Defaults to no filtering: shows all alerts.

Available filters:

* `route_type`
* `route`
* `direction_id`
* `trip`
* `stop`
* `facility`

You can also pass an empty string to only match alerts which don't have a
value for the filter.

### GET /alerts/:id

Returns a single alert, by its ID.

## Health Check

### GET /_health

Returns an HTTP status code 200 if the API has finished loading data, 503 if not.

The contents of the response are for debugging only and are subject to change.

## Predictions

Attributes:

* `direction_id`
* `arrival_time`
* `departure_time`
* `relationship`
* `track`
* `status`

Available includes:

* `stop`
* `route`
* `trip`
* `vehicle`
* `schedule`

### GET /predictions/

Returns a list of predictions for a given route/stop/direction/location.
With no arguments, returns an empty list.

Available filters:

* `latitude`/`longitude` (optional: `radius`): return predictions for stops around a given location
* `route`: return predictions for a comma-separated list of GTFS route IDs
* `trip`: returns predictions for a comma-separated list of GTFS trip IDs
* `stop`: return predictions for a comma-separate list of GTFS stop IDs
* `direction_id`: return predictions for a given direction

These filters can be combined to limit results further.

Available includes:

* `route`
* `schedule`
* `stop`
* `trip`
* `vehicle`

## Routes

Attributes:

* `short_name`
* `long_name`
* `description`
* `type`
* `sort_order`

### GET /routes/

Returns a list of routes.  With no arguments, returns all routes.

Available filters:

* `stop` (optional: `direction_id`): returns routes which stop at a given comma-separated list of GTFS stop IDs
* `type`: returns routes of a given GTFS route type

Available includes:

* `stop` (if `stop` was also used as a filter)

### GET /routes/:id

Return a single route by its GTFS ID.

## Schedules

Attributes:

* `arrival_time`
* `departure_time`
* `stop_sequence`
* `pickup_type`
* `drop_off_type`

Available includes:

* `stop`
* `trip`
* `prediction`

### GET /schedules/

Returns a list of scheduled stops. With no arguments, returns an empty list.

Available filters:

* `date`: returns schedules valid for a given an ISO8601 date string
* `direction_id`: returns schedules for trips going in a particular direction
* `route`: returns schedules for a comma-separated list of GTFS route IDs
* `trip`: returns schedules for a comma-separated list of GTFS trip IDs
* `stop`: returns schedules for a comma-separated list of GTFS stop IDs
* `stop_sequence`: returns schedules in a particular position within a trip.  Can be one of:
  * `first`: the first stop of the trip
  * `last`: the last stop of the trip
  * `<number>`: a particular stop_sequence value from GTFS
* `min_time`: an ISO time "HH:MM" before which schedules should not be returned
* `max_time`: an ISO time "HH:MM" after which schedules should not be returned

These filters can be combined.

## Stops

Attributes:

* `name`
* `latitude`
* `longitude`
* `wheelchair_boarding`

Available includes:

* `parent_station`

### GET /stops/

Returns a list of stops.  With no arguments, returns all stops.

Available filters:

* `route` (optional: `direction_id`): returns stops on a given GTFS route ID, in the order the route takes.
* `route_type`: returns stops on routes with a given GTFS route type
* `latitude`/`longitude` (optional: `radius`): returns stops around a given position.

Available includes:

* `route` (if `route` was used as a filter)

These filters can be combined.

### GET /stops/:id

Returns a stop by its GTFS ID.

## Trips

Attributes:

* `name`
* `headsign`
* `direction_id`
* `wheelchair_accessible`

Available includes:

* `route`
* `vehicle`
* `service`
* `predictions`

### GET /trips/

Returns a list of trips. With no arguments, returns an empty list.

Available filters:

* `route`: returns trips on a GTFS route ID
* `date`: returns trips valid on a given ISO8601 date
* `direction_id`: returns trips traveling in the given direction

These filters can be combined.

### GET /trips/:id

Return a single trip by its GTFS ID.

## Vehicles

Attributes:

* `direction_id`
* `label`
* `latitude`
* `longitude`
* `bearing`
* `current_status`
* `current_stop_sequence`

Available includes:

* `trip`
* `stop`
* `route`

### GET /vehicles/

Returns a list of vehicles currently in service.  With no arguments, returns all vehicles.

Available filters:
* `trip`: returns the vehicles on a comma-separated list of GTFS trip IDs
* `route` (optional `direction_id`): returns a list of vehicles on a comma-separated list of GTFS route IDs

These filters can not be combined.

### GET /vehicles/:id

Return the status of a single vehicle by its ID.
