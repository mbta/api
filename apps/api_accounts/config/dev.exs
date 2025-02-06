import Config

config :api_accounts, table_prefix: "DEV"

config :api_accounts, ApiAccounts.Mailer, adapter: Bamboo.LocalAdapter
