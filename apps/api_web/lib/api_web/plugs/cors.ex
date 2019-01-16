defmodule ApiWeb.Plugs.CORS do
  @moduledoc """
  Sends appropriate CORS headers based on configuration of key.
  """

  import Plug.Conn
  import Corsica
  import Phoenix.Controller, only: [render: 3, put_view: 2]

  def init(opts), do: opts

  def call(%{assigns: assigns} = conn, _) do
    allowed_domains = parse_allowed_domains(assigns.user.allowed_domains)

    if origin_allowed(conn, allowed_domains) do
      put_cors_simple_resp_headers(
        conn,
        origins: allowed_domains
      )
    else
      conn
      |> put_status(:bad_request)
      |> put_view(ApiWeb.ErrorView)
      |> render("400.json-api", error: :allowed_domain)
      |> halt()
    end
  end

  defp parse_allowed_domains(nil), do: "*"
  defp parse_allowed_domains("*"), do: "*"

  defp parse_allowed_domains(allowed_domains) do
    allowed_domains
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp origin_allowed(_, "*"), do: true

  defp origin_allowed(conn, allowed_domains) do
    Enum.any?(get_req_header(conn, "origin"), fn x -> x in allowed_domains end)
  end
end
