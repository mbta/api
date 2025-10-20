defmodule ApiAccountsTest do
  use ExUnit.Case, async: true

  alias ApiAccounts.Key

  describe "keys" do
    test "get_key!/1 returns a key if DynamoDB is disabled" do
      config = Application.get_env(:ex_aws, :dynamodb)
      on_exit fn ->
      Application.put_env(:ex_aws, :dynamodb, config)
      end
      Application.put_env(:ex_aws, :dynamodb, [enabled: false] ++ config)

      assert key = %Key{} = ApiAccounts.get_key!("bad_id")
      assert key.approved
    end
    end
end
