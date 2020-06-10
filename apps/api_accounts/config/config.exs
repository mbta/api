# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :ex_aws,
  dynamodb: [
    port: "8000",
    scheme: "http://",
    host: "localhost"
  ]

config :ex_aws, :hackney_opts,
  recv_timeout: 30_000,
  pool: :ex_aws_pool

config :api_accounts, ApiAccounts.Mailer, adapter: Bamboo.SesAdapter

config :api_accounts, migrate_on_start: false

import_config "#{Mix.env()}.exs"
