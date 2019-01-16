defmodule ApiWeb.ClientPortal.PortalController do
  @moduledoc false
  use ApiWeb.Web, :controller

  def landing(conn, _params) do
    conn
    |> assign(:pre_container_template, "_hero.html")
    |> render("landing.html")
  end

  def index(conn, _params) do
    keys = ApiAccounts.list_keys_for_user(conn.assigns.user)

    render(
      conn,
      "index.html",
      keys: keys,
      api_versions: Application.get_env(:api_web, :versions)[:versions]
    )
  end
end
