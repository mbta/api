use Mix.Config

config :ex_aws,
  dynamodb: [
    # make sure port is first, otherwise it won't be converted to an integer
    port: "${DYNAMO_PORT}",
    scheme: "${DYNAMO_SCHEME}",
    host: "${DYNAMO_HOST}"
  ]

config :api_accounts,
  table_prefix: "${DYNAMO_TABLE_PREFIX}",
  migrate_on_start: true
