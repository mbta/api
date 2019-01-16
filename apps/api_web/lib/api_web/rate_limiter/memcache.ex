defmodule ApiWeb.RateLimiter.Memcache do
  @moduledoc """
  RateLimiter backend which uses Memcache as a backend.
  """
  @behaviour ApiWeb.RateLimiter.Limiter

  @impl ApiWeb.RateLimiter.Limiter
  def start_link(opts) do
    clear_interval_ms = Keyword.fetch!(opts, :clear_interval)
    clear_interval = div(clear_interval_ms, 1000)

    connection_opts =
      [ttl: clear_interval] ++ ApiWeb.config(RateLimiter.Memcache, :connection_opts)

    Memcache.start_link(connection_opts, name: __MODULE__)
  end

  @impl ApiWeb.RateLimiter.Limiter
  def rate_limited?(user_id, max_requests) do
    Memcache.decr(__MODULE__, user_id, default: max_requests) == {:ok, 0}
  end
end
