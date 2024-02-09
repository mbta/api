import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :api_web, ApiWeb.Endpoint,
  http: [port: 4001],
  server: false

config :api_web, :rate_limiter,
  max_anon_per_interval: 5,
  clear_interval: 100

config :api_web, RateLimiter.Memcache,
  connection_opts: [
    namespace: "api_test_rate_limit",
    hostname: "localhost"
  ]

config :api_web, ApiWeb.Plugs.ModifiedSinceHandler, check_caller: true

# Credentials that always show widget and pass backend validation:
config :recaptcha,
  enabled: true,
  public_key: "6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI",
  secret: "6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe"

# Print only warnings and errors during test
config :logger, level: :warn
