use Mix.Config

config :comeonin, bcrypt_log_rounds: 4

config :api_accounts, table_prefix: "TEST"

config :ex_aws,
  access_key_id: "",
  secret_access_key: ""

config :api_accounts, ApiAccounts.Mailer, adapter: Bamboo.TestAdapter
