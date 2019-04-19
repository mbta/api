defmodule ApiWeb.Plugs.RateLimiter do
  @moduledoc """
  Rate limits a user based on their API key or by their IP address if no
  API key is provided.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [render: 3, put_view: 2]

  def init(opts), do: opts

  def call(%{assigns: assigns, request_path: request_path} = conn, _) do
    case ApiWeb.RateLimiter.log_request(assigns.api_user, request_path) do
      :ok ->
        conn

      {:ok, {limit, remaining, reset_ms}} ->
        conn
        |> put_rate_limit_headers(limit, remaining, reset_ms)

      {:rate_limited, {limit, remaining, reset_ms}} ->
        conn
        |> put_rate_limit_headers(limit, remaining, reset_ms)
        |> put_status(429)
        |> put_view(ApiWeb.ErrorView)
        |> render("429.json-api", [])
        |> halt()
    end
  end

  defp put_rate_limit_headers(conn, limit, remaining, reset_ms) do
    reset_seconds = div(reset_ms, 1_000)

    conn
    |> put_resp_header("x-ratelimit-limit", "#{limit}")
    |> put_resp_header("x-ratelimit-remaining", "#{remaining}")
    |> put_resp_header("x-ratelimit-reset", "#{reset_seconds}")
  end
end
