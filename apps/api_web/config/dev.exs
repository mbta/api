use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :api_web, ApiWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  secret_key_base: "v1EHfW07QPr8ai7bi0hooadtBorROPNjhSWx7CGv7AiCOhEyGoeT1jagMTNCE3PU",
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{lib/api_web/views/.*(ex)$},
      ~r{lib/api_web/templates/.*(eex)$}
    ]
  ]

config :api_web, :signing_salt, "NdisAeo6Jf02spiKqa"

config :api_web, ApiWeb.Plugs.ModifiedSinceHandler, check_caller: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n", level: :debug

# Set a higher stacktrace during development.
# Do not configure such in production as keeping
# and calculating stacktraces is usually expensive.
config :phoenix, :stacktrace_depth, 20
