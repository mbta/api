defmodule ApiWeb.HealthController do
  use ApiWeb.Web, :controller

  def index(conn, _params) do
    health = Health.Checker.current()

    status =
      if Health.Checker.healthy?() do
        :ok
      else
        :service_unavailable
      end

    body =
      health
      |> Enum.into(%{})
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end
end
