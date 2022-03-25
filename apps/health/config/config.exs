# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :health,
  checkers: [
    Health.Checkers.State,
    Health.Checkers.RunQueue,
    Health.Checkers.RealTime,
    Health.Checkers.Ports
  ]

config :health, Health.Checkers.Ports, max_ports: 250
