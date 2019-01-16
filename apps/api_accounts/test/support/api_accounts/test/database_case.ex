defmodule ApiAccounts.Test.DatabaseCase do
  @moduledoc """
  Template for tests that rely on DynamoDB interactions.
  """
  use ExUnit.CaseTemplate

  setup do
    ApiAccounts.Dynamo.delete_all_tables()
    {:ok, _} = ApiAccounts.Dynamo.create_table(ApiAccounts.User)
    {:ok, _} = ApiAccounts.Dynamo.create_table(ApiAccounts.Key)
    on_exit(fn -> ApiAccounts.Dynamo.delete_all_tables() end)
  end
end
