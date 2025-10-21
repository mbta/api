defmodule ApiWeb.Plugs.CORS do
  @moduledoc """
  Sends appropriate CORS headers based on configuration of key.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [render: 3, put_view: 2]

  alias Corsica

  @default_opts Corsica.sanitize_opts(
                  origins: "*",
                  allow_methods: :all,
                  allow_headers: [
                    "x-api-key",
                    "accept-encoding",
                    "if-none-match",
                    "if-modified-since"
                  ]
                )

  def init(opts), do: opts

  def call(%{assigns: assigns} = conn, _) do
    if Corsica.cors_req?(conn) do
      allowed_domains = parse_allowed_domains(assigns.api_user.allowed_domains)
      opts = %{@default_opts | origins: allowed_domains}

      cond do
        Corsica.preflight_req?(conn) ->
          Corsica.send_preflight_resp(conn, opts)

        Corsica.allowed_origin?(conn, opts) ->
          Corsica.put_cors_simple_resp_headers(conn, opts)

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

  defp render_400(conn) do
    conn
    |> put_status(:bad_request)
    |> put_view(ApiWeb.ErrorView)
    |> render("400.json-api", error: :allowed_domain)
    |> halt()
  end
end
