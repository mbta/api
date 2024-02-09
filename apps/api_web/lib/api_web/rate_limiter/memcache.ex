defmodule ApiWeb.RateLimiter.Memcache do
  @moduledoc """
  RateLimiter backend which uses Memcache as a backend.
  """
  @behaviour ApiWeb.RateLimiter.Limiter
  alias ApiWeb.RateLimiter.Memcache.Supervisor

  @impl ApiWeb.RateLimiter.Limiter
  def start_link(opts) do
    clear_interval_ms = Keyword.fetch!(opts, :clear_interval)
    clear_interval = div(clear_interval_ms, 1000)

    connection_opts =
      [ttl: clear_interval * 2] ++ ApiWeb.config(RateLimiter.Memcache, :connection_opts)

    Supervisor.start_link(connection_opts)
  end

  @impl ApiWeb.RateLimiter.Limiter
  def rate_limited?(key, max_requests) do
    case Supervisor.decr(key, default: max_requests) do
      {:ok, 0} ->
        :rate_limited

      {:ok, n} when is_integer(n) ->
        {:remaining, n - 1}

      _ ->
        {:remaining, max_requests}
    end
  end
end
