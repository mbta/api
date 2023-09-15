# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :state_mediator, start: config_env() != :test

config :state_mediator, :commuter_rail_crowding,
  firebase_url: {
    :system,
    "CR_CROWDING_BASE_URL",
    "https://keolis-api-development.firebaseio.com/p-kcs-trms-firebase-7dayloading.json"
  },
  enabled: {:system, "CR_CROWDING_ENABLED", "false"}

config :state_mediator, Realtime,
  gtfs_url: {:system, "MBTA_GTFS_URL", "https://cdn.mbta.com/MBTA_GTFS.zip"},
  alert_url: {:system, "ALERT_URL", "https://cdn.mbta.com/realtime/Alerts_enhanced.json"}

config :state_mediator, State.Prediction,
  source: {
    :system,
    "MBTA_TRIP_SOURCE",
    "https://cdn.mbta.com/realtime/TripUpdates_enhanced.json"
  }

config :state_mediator, State.Vehicle,
  source: {
    :system,
    "MBTA_VEHICLE_SOURCE",
    "https://cdn.mbta.com/realtime/VehiclePositions_enhanced.json"
  },
  username: {:system, "MBTA_VEHICLE_USERNAME", nil},
  password: {:system, "MBTA_VEHICLE_PASSWORD", nil}

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :state_mediator, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:state_mediator, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
import_config "#{config_env()}.exs"
