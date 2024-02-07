defmodule ApiWeb.RateLimiter.Memcache do
  @moduledoc """
  RateLimiter backend which uses Memcache as a backend.
  """
  @behaviour ApiWeb.RateLimiter.Limiter
  alias ApiWeb.RateLimiter.Memcache.Supervisor

  @impl true
  def start_link(_) do
    {:ok, self()}
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
