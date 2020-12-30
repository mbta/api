# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :health,
  checkers: [
    Health.Checkers.State,
    Health.Checkers.RunQueue,
    Health.Checkers.RealTime
  ]
