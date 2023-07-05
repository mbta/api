import Config

config :api_accounts, table_prefix: "DEV"

config :ex_aws,
  access_key_id: "DevAccessKey",
  secret_access_key: "DevSecretKey"

config :api_accounts, ApiAccounts.Mailer, adapter: Bamboo.LocalAdapter
