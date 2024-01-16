defmodule ApiWeb.Plugs.RateLimiterConcurrent do
  @moduledoc """
  Plug to invoke the concurrent rate limiter.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [render: 3, put_view: 2]

  alias ApiWeb.RateLimiter.RateLimiterConcurrent

  def init(opts), do: opts

  def call(conn, _opts) do
    if enabled?() do
      event_stream? = Plug.Conn.get_req_header(conn, "accept") == ["text/event-stream"]

      {at_limit?, remaining, limit} =
        RateLimiterConcurrent.check_concurrent_rate_limit(conn.assigns.api_user, event_stream?)

      # Allow negative limits to allow unlimited use:
      if limit >= 0 and at_limit? do
        conn
        |> put_concurrent_rate_limit_headers(limit, remaining)
        |> put_status(429)
        |> put_view(ApiWeb.ErrorView)
        |> render("429.json-api", [])
        |> halt()
      else
        RateLimiterConcurrent.add_lock(conn.assigns.api_user, self(), event_stream?)

        conn
        |> put_concurrent_rate_limit_headers(limit, remaining - 1)
        |> register_before_send(fn conn ->
          RateLimiterConcurrent.remove_lock(conn.assigns.api_user, self(), event_stream?)
          conn
        end)
      end
    else
      conn
    end
  end

  defp put_concurrent_rate_limit_headers(conn, limit, remaining) do
    conn
    |> put_resp_header("x-concurrent-ratelimit-limit", "#{limit}")
    |> put_resp_header("x-concurrent-ratelimit-remaining", "#{remaining}")
  end

  def enabled? do
    Keyword.fetch!(Application.get_env(:api_web, :rate_limiter_concurrent), :enabled) == true
  end
end
