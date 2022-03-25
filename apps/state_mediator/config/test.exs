import Config

config :state_mediator, State.FakeModuleA, source: {:system, "FAKE_VAR_A", "default_a"}

config :state_mediator, State.FakeModuleB, source: {:system, "FAKE_VAR_B", "default_b"}

config :state_mediator, State.FakeModuleC, source: "default_c"

# Record the original working directory so that when it changes during the
# test run, we can still find the MBTA_GTFS_FILE.
config :state_mediator, :cwd, File.cwd!()
