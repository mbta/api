# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# Configures the endpoint
config :api_web, ApiWeb.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "v1EHfW07QPr8ai7bi0hooadtBorROPNjhSWx7CGv7AiCOhEyGoeT1jagMTNCE3PU",
  render_errors: [accepts: ~w(json html)],
  http: [
    compress: true,
    protocol_options: [idle_timeout: 86_400_000, request_timeout: 120_000]
  ]

config :api_web, :signing_salt, "NdisAeo6Jf02spiKqa"

config :api_web, :rate_limiter,
  clear_interval: 60_000,
  limiter: ApiWeb.RateLimiter.ETS,
  max_anon_per_interval: 5_000,
  max_registered_per_interval: 100_000,
  wait_time_ms: 0

config :api_web, ApiWeb.Plugs.ModifiedSinceHandler, check_caller: false

config :api_web, :api_pipeline,
  authenticated_accepts: [],
  accepts: ["json", "json-api", "event-stream"]

config :api_web, :versions,
  versions: [
    "2017-11-28",
    "2018-05-07",
    "2018-07-23",
    "2019-02-12",
    "2019-04-05",
    "2019-07-01",
    "2020-05-01",
    "2021-01-09"
  ],
  default: "2021-01-09"

config :logger, :console,
  format: "$date $time $metadata[$level] $message\n",
  metadata: [:request_id]

# JSON-API configuration
config :phoenix, json_library: Jason

config :phoenix, :format_encoders,
  "json-api": Jason,
  json: Jason

config :mime, :types, %{
  "application/vnd.api+json" => ["json-api"],
  "text/event-stream" => ["event-stream"]
}

config :ja_serializer, key_format: :underscored

config :recaptcha,
  verify_url: "https://www.google.com/recaptcha/api/siteverify",
  enabled: false

config :api_web, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [router: ApiWeb.Router, endpoint: ApiWeb.Endpoint]
  }

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
