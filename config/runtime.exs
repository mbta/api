import Config

is_prod? = config_env() == :prod
is_release? = not is_nil(System.get_env("RELEASE_MODE"))

if is_prod? and is_release? do
  config :tzdata, :autoupdate, :disabled

  sentry_env = System.get_env("SENTRY_ENV")

  if not is_nil(sentry_env) do
    config :sentry,
      filter: ApiWeb.SentryEventFilter,
      dsn: System.fetch_env!("SENTRY_DSN"),
      environment_name: sentry_env,
      enable_source_code_context: true,
      root_source_code_path: File.cwd!(),
      tags: %{
        env: sentry_env
      },
      included_environments: [sentry_env]

    config :logger, Sentry.LoggerBackend, level: :error
  end

  config :ex_aws,
    dynamodb: [
      port: "DYNAMO_PORT" |> System.get_env("443") |> String.to_integer(),
      scheme: System.get_env("DYNAMO_SCHEME", "https://"),
      host: System.fetch_env!("DYNAMO_HOST")
    ],
    json_codec: Jason


  config :alb_monitor,
    ecs_metadata_uri: System.fetch_env!("ECS_CONTAINER_METADATA_URI"),
    target_group_arn: System.fetch_env!("ALB_TARGET_GROUP_ARN")

  config :api_accounts,
    table_prefix: System.fetch_env!("DYNAMO_TABLE_PREFIX"),
    migrate_on_start: true

  config :api_web, RateLimiter.Memcache,
    connection_opts: [
      namespace: System.fetch_env!("HOST"),
      hostname: System.fetch_env!("MEMCACHED_HOST")
    ]

  config :state_mediator, Realtime,
    gtfs_url: System.fetch_env!("MBTA_GTFS_URL"),
    alert_url: System.fetch_env!("ALERT_URL")

  config :state_mediator, State.Prediction, source: System.fetch_env!("MBTA_TRIP_SOURCE")

  config :state_mediator, State.Vehicle, source: System.fetch_env!("MBTA_VEHICLE_SOURCE")

  config :api_web, signing_salt: System.fetch_env!("SIGNING_SALT")

  config :api_web, ApiWeb.Endpoint,
    http: [
      port: System.fetch_env!("PORT")
    ],
    url: [
      host: System.fetch_env!("HOST")
    ],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")

  config :state_mediator, :commuter_rail_crowding,
    firebase_credentials: System.fetch_env!("CR_CROWDING_FIREBASE_CREDENTIALS")

  config :recaptcha,
    enabled: true,
    public_key: System.fetch_env!("RECAPTCHA_PUBLIC_KEY"),
    secret: System.fetch_env!("RECAPTCHA_PRIVATE_KEY")
end
