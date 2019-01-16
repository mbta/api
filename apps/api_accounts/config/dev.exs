use Mix.Config

config :api_accounts, table_prefix: "DEV"

config :ex_aws,
  access_key_id: "",
  secret_access_key: ""

config :api_accounts, ApiAccounts.Mailer, adapter: Bamboo.LocalAdapter
