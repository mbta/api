defmodule ApiWeb.RateLimiter.Memcache.Supervisor do
  @moduledoc """
  Supervisor for multiple connections to a Memcache instance.
  """
  @worker_count 5
  @registry_name __MODULE__.Registry
  @rate_limit_config Application.compile_env!(:api_web, :rate_limiter)

  use Agent

  def start_link(_) do
    registry = {Registry, keys: :unique, name: @registry_name}

    children =
      if memcache_required?() do
        clear_interval_ms = Keyword.fetch!(@rate_limit_config, :clear_interval)
        clear_interval = div(clear_interval_ms, 1000)

        connection_opts_config =
          Application.fetch_env!(:api_web, RateLimiter.Memcache)
          |> Keyword.fetch!(:connection_opts)

        connection_opts = [ttl: clear_interval * 2] ++ connection_opts_config

        workers =
          for i <- 1..@worker_count do
            Supervisor.child_spec({Memcache, [connection_opts, [name: worker_name(i)]]}, id: i)
          end

        [registry | workers]
      else
        [registry]
      end

    Supervisor.start_link(
      children,
      strategy: :rest_for_one,
      name: __MODULE__
    )
  end

  @doc "Decrement a given key, using a random child."
  def decr(key, opts) do
    Memcache.decr(random_child(), key, opts)
  end

  defp worker_name(index) do
    {:via, Registry, {@registry_name, index}}
  end

  defp memcache_required? do
    (ApiWeb.RateLimiter.RateLimiterConcurrent.enabled?() and
       ApiWeb.RateLimiter.RateLimiterConcurrent.memcache?()) or
      ApiWeb.config(:rate_limiter, :limiter) == ApiWeb.RateLimiter.Memcache
  end

  def random_child do
    worker_name(:rand.uniform(@worker_count))
  end
end
