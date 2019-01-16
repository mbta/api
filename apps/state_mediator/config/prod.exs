use Mix.Config

config :state_mediator, Realtime,
  gtfs_url: "${MBTA_GTFS_URL}",
  alert_url: "${ALERT_URL}"

config :state_mediator, State.Prediction, source: "${MBTA_TRIP_SOURCE}"

config :state_mediator, State.Vehicle, source: "${MBTA_VEHICLE_SOURCE}"
