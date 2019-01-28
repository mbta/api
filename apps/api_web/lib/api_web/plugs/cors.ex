defmodule ApiWeb.Plugs.CORS do
  @moduledoc """
  Sends appropriate CORS headers based on configuration of key.
  """

  @default_opts [
    allow_methods: :all
  ]

  import Plug.Conn
  import Corsica
  import Phoenix.Controller, only: [render: 3, put_view: 2]

  def init(opts), do: opts

  def call(%{assigns: assigns} = conn, _) do
    if cors_req?(conn) do
      allowed_domains = parse_allowed_domains(assigns.api_user.allowed_domains)
      opts = [origins: allowed_domains] ++ @default_opts

      cond do
        preflight_req?(conn) ->
          send_preflight_resp(conn, opts)

        origin_allowed?(conn, allowed_domains) ->
          put_cors_simple_resp_headers(conn, opts)

        true ->
          render_400(conn)
      end
    else
      conn
    end
  end

  defp parse_allowed_domains(nil), do: "*"
  defp parse_allowed_domains("*"), do: "*"

  defp parse_allowed_domains(allowed_domains) do
    allowed_domains
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp origin_allowed?(_, "*"), do: true

  defp origin_allowed?(conn, allowed_domains) do
    conn
    |> get_req_header("origin")
    |> Enum.any?(fn x -> x in allowed_domains end)
  end

  defp render_400(conn) do
    conn
    |> put_status(:bad_request)
    |> put_view(ApiWeb.ErrorView)
    |> render("400.json-api", error: :allowed_domain)
    |> halt()
  end
end
