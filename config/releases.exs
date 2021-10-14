import Config

config :ex_aws,
  dynamodb: [
    port: "DYNAMO_PORT" |> System.get_env() |> String.to_integer(),
    scheme: System.get_env("DYNAMO_SCHEME"),
    host: System.get_env("DYNAMO_HOST")
  ]

config :alb_monitor,
  ecs_metadata_uri: System.get_env("ECS_CONTAINER_METADATA_URI"),
  target_group_arn: System.get_env("ALB_TARGET_GROUP_ARN")

config :api_accounts,
  table_prefix: System.get_env("DYNAMO_TABLE_PREFIX"),
  migrate_on_start: true

config :api_web, RateLimiter.Memcache,
  connection_opts: [
    namespace: System.get_env("HOST"),
    hostname: System.get_env("MEMCACHED_HOST")
  ]

config :state_mediator, Realtime,
  gtfs_url: System.get_env("MBTA_GTFS_URL"),
  alert_url: System.get_env("ALERT_URL")

config :state_mediator, State.Prediction, source: System.get_env("MBTA_TRIP_SOURCE")

config :state_mediator, State.Vehicle, source: System.get_env("MBTA_VEHICLE_SOURCE")
