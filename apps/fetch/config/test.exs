use Mix.Config

config :fetch, FileTap,
  module: Fetch.FileTap.MockTap,
  max_tap_size: 100
