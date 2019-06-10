use Mix.Config

config :state_mediator, State.FakeModuleA, source: {:system, "FAKE_VAR_A", "default_a"}

config :state_mediator, State.FakeModuleB, source: {:system, "FAKE_VAR_B", "default_b"}

config :state_mediator, State.FakeModuleC, source: "default_c"

config :state_mediator, GtfsTestModules, [
  {"routes", State.Route,
   minimum_size: 5,
   required_fields: [
     # you can't quote a function, so we use the {module, func, args} pattern
     # instead
     id: {Kernel, :is_binary, []},
     short_name: {Kernel, :is_binary, []},
     long_name: {Kernel, :is_binary, []},
     type: {:lists, :member, [[0, 1, 2, 3, 4]]}
   ]},
  {"trips", State.Trip,
   minimum_size: 100,
   required_fields: [
     id: {Kernel, :is_binary, []},
     name: {Kernel, :is_binary, []},
     direction_id: {:lists, :member, [[0, 1]]},
     route_id: {State.Route, :by_id, []},
     service_id: {State.Service, :by_id, []}
   ]},
  {"stops", State.Stop,
   required_fields: [
     id: {Kernel, :is_binary, []},
     name: {Kernel, :is_binary, []},
     latitude: {Kernel, :is_float, []},
     longitude: {Kernel, :is_float, []}
   ]},
  {"schedules", State.Schedule,
   required_fields: [
     stop_id: {State.Stop, :by_id, []},
     trip_id: {State.Trip, :by_id, []},
     route_id: {State.Route, :by_id, []},
     stop_sequence: {Kernel, :>=, [0]}
   ]}
]

# Record the original working directory so that when it changes during the
# test run, we can still find the MBTA_GTFS_FILE.
config :state_mediator, :cwd, File.cwd!()
