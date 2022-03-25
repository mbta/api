# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :parse, Facility.Parking,
  garages: %{
    "Alewife" => "park-alfcl-garage",
    "Braintree" => "park-brntn-garage",
    "Woodland" => "park-woodl-garage",
    "DataPark" => "park-woodl-garage",
    "MBTA BEVERLY" => "park-ER-0183-garage",
    "MBTA Route 128" => "park-NEC-2173-garage",
    "MBTA SALEM" => "park-ER-0168-garage",
    "MBTA SALEM " => "park-ER-0168-garage",
    "Quincy Adams" => "park-qamnl-garage",
    "Wonderland" => "park-wondl-garage"
  }

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :parse, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:parse, :key)
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
#     import_config "#{Mix.env}.exs"
