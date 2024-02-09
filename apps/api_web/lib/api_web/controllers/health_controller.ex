defmodule ApiWeb.HealthController do
  use ApiWeb.Web, :controller

  require Logger

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

    _ = log_health_check(health, status)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end

  defp log_health_check(health, :service_unavailable) do
    Logger.info("health_check healthy=false #{inspect(health)}")
  end

  defp log_health_check(_, _), do: :ignored
end
