defmodule ApiWeb.RateLimiter.Limiter do
  @moduledoc """
  Behavior for backends to the V3 API rate limiter.

  - `start_link(opts)` is called to start the backend by the supervisor.
  - `rate_limited?(user_id, max_requests)` returns true if the user_id has used too many requests, along with the number of requests the user_id has used in this time period.

  The main option passed to `start_link/1` is `clear_interval` which is a
  number of milliseconds to bucket the requests into.

  """
  @callback start_link(Keyword.t()) :: {:ok, pid}
  @callback rate_limited?(String.t(), non_neg_integer) :: {boolean, non_neg_integer}
  @callback clear() :: :ok
  @callback list() :: [String.t()]

  @optional_callbacks [clear: 0, list: 0]
end
