defmodule ApiWeb.Plugs.RateLimiterConcurrent do
  @moduledoc """
  Plug to invoke the concurrent rate limiter.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [render: 3, put_view: 2]

  require Logger

  alias ApiWeb.RateLimiter.RateLimiterConcurrent

  @rate_limit_concurrent_config Application.compile_env!(:api_web, :rate_limiter_concurrent)

  def init(opts), do: opts

  def call(conn, _opts) do
    if enabled?() do
      event_stream? = Plug.Conn.get_req_header(conn, "accept") == ["text/event-stream"]

      {at_limit?, remaining, limit} =
        RateLimiterConcurrent.check_concurrent_rate_limit(conn.assigns.api_user, event_stream?)

      if log_statistics?() do
        Logger.info(
          "ApiWeb.Plugs.RateLimiterConcurrent event=request_statistics api_user=#{conn.assigns.api_user.id} at_limit=#{at_limit?} remaining=#{remaining - 1} limit=#{limit} event_stream=#{event_stream?}"
        )
      end

      # Allow negative limits to allow unlimited use:
      if limit_users?() and limit >= 0 and at_limit? do
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
    Keyword.fetch!(@rate_limit_concurrent_config, :enabled)
  end

  def limit_users? do
    Keyword.fetch!(@rate_limit_concurrent_config, :limit_users)
  end

  def log_statistics? do
    Keyword.fetch!(@rate_limit_concurrent_config, :log_statistics)
  end
end
