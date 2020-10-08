import Config

config :ex_aws,
  dynamodb: [
    # make sure port is first, otherwise it won't be converted to an integer
    port: System.get_env("DYNAMO_PORT"),
    scheme: System.get_env("DYNAMO_SCHEME"),
    host: System.get_env("DYNAMO_HOST")
  ]

config :api_accounts,
  table_prefix: System.get_env("DYNAMO_TABLE_PREFIX"),
  migrate_on_start: true

config :api_web, ApiWeb.Endpoint, secret_key_base: System.get_env("SECRET_KEY_BASE")

config :api_web, :signing_salt, System.get_env("SIGNING_SALT")

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
