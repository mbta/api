import Config

config :bcrypt_elixir, log_rounds: 4

config :api_accounts, table_prefix: "TEST"

config :ex_aws,
  access_key_id: "TestAccessKey",
  secret_access_key: "TestSecretKey"

config :api_accounts, ApiAccounts.Mailer, adapter: Bamboo.TestAdapter
