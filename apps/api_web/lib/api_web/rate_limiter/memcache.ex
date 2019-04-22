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
      [ttl: clear_interval * 2] ++ ApiWeb.config(RateLimiter.Memcache, :connection_opts)

    Memcache.start_link(connection_opts, name: __MODULE__)
  end

  @impl ApiWeb.RateLimiter.Limiter
  def rate_limited?(key, max_requests) do
    case Memcache.decr(__MODULE__, key, default: max_requests) do
      {:ok, 0} ->
        :rate_limited

      {:ok, n} when is_integer(n) ->
        {:remaining, n - 1}

      _ ->
        {:remaining, max_requests}
    end
  end
end
