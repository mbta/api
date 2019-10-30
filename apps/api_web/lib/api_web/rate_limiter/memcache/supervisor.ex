defmodule ApiWeb.RateLimiter.Memcache.Supervisor do
  @moduledoc """
  Supervisor for multiple connections to a Memcache instance.
  """
  require Logger

  @worker_count 5
  @registry_name __MODULE__.Registry

  def start_link(connection_opts) do
    registry = {Registry, keys: :unique, name: @registry_name}

    workers =
      for i <- 1..@worker_count do
        Supervisor.child_spec({Memcache, [connection_opts, [name: worker_name(i)]]}, id: i)
      end

    children = [registry | workers]

    Supervisor.start_link(
      children,
      strategy: :rest_for_one,
      name: __MODULE__
    )
  end

  @doc "Decrement a given key, using a random child."
  def decr(key, opts) do
    child = random_child()
    _ = Logger.debug(fn -> "Memcache decr using child #{child}" end)
    Memcache.decr(child, key, opts)
  end

  defp worker_name(index) do
    {:via, Registry, {@registry_name, index}}
  end

  defp random_child do
    worker_name(:random.uniform(@worker_count))
  end
end
