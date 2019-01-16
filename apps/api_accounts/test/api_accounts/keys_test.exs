defmodule ApiAccounts.KeysTest do
  use ApiAccounts.Test.DatabaseCase, async: false

  alias ApiAccounts.{Key, Keys}

  @cached_valid_key %Key{key: String.duplicate("v", 32), user_id: "user", approved: true}

  setup do
    Keys.cache_key(@cached_valid_key)
    :ok
  end

  test "start_link" do
    {status, _} = Keys.start_link(name: :test_api_key)
    assert status == :ok
    refute :ets.info(Keys.table_name()) == :undefined
  end

  test "cache_key/1" do
    Keys.cache_key(%Key{key: "1"})
    assert get_key_from_table("1")
  end

  test "revoke_key/1" do
    key = %Key{key: "1"}
    Keys.cache_key(key)
    Keys.revoke_key(key)
    refute get_key_from_table(key.key)
  end

  describe "fetch_valid_key/1" do
    test "returns a key is found in the cache" do
      assert Keys.fetch_valid_key(@cached_valid_key.key) == {:ok, @cached_valid_key}
    end

    test "validates and caches valid V3 keys" do
      valid = @cached_valid_key
      unapproved = %Key{key: String.duplicate("u", 32), user_id: "user"}
      locked = %Key{key: String.duplicate("l", 32), user_id: "user", approved: true, locked: true}
      {:ok, _} = ApiAccounts.Dynamo.put_item(valid)
      {:ok, _} = ApiAccounts.Dynamo.put_item(unapproved)
      {:ok, _} = ApiAccounts.Dynamo.put_item(locked)

      assert Keys.fetch_valid_key(valid.key) == {:ok, valid}
      assert get_key_from_table(valid.key)

      assert {:error, :not_found} == Keys.fetch_valid_key(unapproved.key)
      refute get_key_from_table(unapproved.key)

      assert {:error, :not_found} == Keys.fetch_valid_key(locked.key)
      refute get_key_from_table(locked.key)
    end

    test "returns error for invalid keys" do
      assert Keys.fetch_valid_key("bad_key") == {:error, :not_found}
    end

    test "fetches an updated key (after update)" do
      key = @cached_valid_key
      updated_key = %{key | daily_limit: 5_000}
      {:ok, _} = ApiAccounts.Dynamo.put_item(updated_key)
      Keys.update!()
      assert Keys.fetch_valid_key(key.key) == {:ok, updated_key}
    end

    test "removed an invalidated key" do
      key = @cached_valid_key
      locked_key = %{key | locked: true}
      {:ok, key} = ApiAccounts.Dynamo.put_item(locked_key)
      Keys.update!()

      assert Keys.fetch_valid_key(key.key) == {:error, :not_found}
    end
  end

  defp get_key_from_table(key) do
    case :ets.lookup(Keys.table_name(), key) do
      [{^key, cached_key}] -> cached_key
      _ -> nil
    end
  end
end
