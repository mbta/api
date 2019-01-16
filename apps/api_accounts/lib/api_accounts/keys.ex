defmodule ApiAccounts.Keys do
  @moduledoc """
  Validates and caches API keys.

  When validating a key, the API key is looked up in the cache. If a key isn't
  present in the cache, the key will be validated against the V2 API and V3 set
  of API keys and stored in the cache if it's a valid key.
  """
  use GenServer
  alias ApiAccounts.Key

  @table :api_key_cache
  @fetch_timeout 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  def init(_opts) do
    table_opts = [:set, :named_table, :public, read_concurrency: true]

    _ =
      if :ets.info(table_name()) == :undefined do
        :ets.new(table_name(), table_opts)
      end

    schedule_timeout!()
    {:ok, %{}}
  end

  defp schedule_timeout! do
    Process.send_after(self(), :timeout, @fetch_timeout)
  end

  def handle_call(:update!, _, state) do
    _ = handle_info(:timeout, state)
    {:reply, :ok, state}
  end

  def handle_info(:timeout, state) do
    :ets.foldl(&update_keys/2, :ok, @table)

    schedule_timeout!()
    {:noreply, state}
  end

  defp update_keys({key_id, key}, :ok) do
    case fetch_key_remote(key_id) do
      [] ->
        :ets.delete(@table, key_id)

      [^key] ->
        # same key
        :ok

      [new_key] ->
        # new key
        :ets.insert(@table, {key_id, new_key})
    end

    :ok
  end

  @spec fetch_key(String.t()) :: {:ok, Key.t()} | {:error, :not_found}
  defp fetch_key(key) do
    case fetch_key_remote(key) do
      [key] ->
        cache_key(key)
        {:ok, key}

      [] ->
        {:error, :not_found}
    end
  end

  defp fetch_key_remote(key) when byte_size(key) == 32 do
    case ApiAccounts.get_key(key) do
      {:ok, %Key{approved: true, locked: false} = key} -> [key]
      _ -> []
    end
  end

  defp fetch_key_remote(_key) do
    []
  end

  @doc """
  Caches a key in ETS.
  """
  @spec cache_key(Key.t()) :: true
  def cache_key(%Key{key: key} = struct) do
    :ets.insert(table_name(), {key, struct})
  end

  @doc """
  Removes a key from ETS.
  """
  @spec revoke_key(Key.t()) :: true
  def revoke_key(%Key{key: key}) do
    :ets.delete(table_name(), key)
  end

  @doc false
  def table_name, do: @table

  @doc """
  Fetches a Key if it is valid.
  """
  @spec fetch_valid_key(String.t()) :: {:ok, Key.t()} | {:error, :not_found}
  def fetch_valid_key(api_key) do
    case :ets.lookup(table_name(), api_key) do
      [{^api_key, key}] -> {:ok, key}
      [] -> fetch_key(api_key)
    end
  end

  @doc false
  def update! do
    # test-only function
    :ok = GenServer.call(__MODULE__, :update!)
  end
end
