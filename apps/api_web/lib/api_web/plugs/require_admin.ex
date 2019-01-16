defmodule ApiWeb.Plugs.RequireAdmin do
  @moduledoc """
  Plug enforcing a user to have the administrator role.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [render: 3, put_view: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> fetch_user()
    |> authenticate(conn)
  end

  defp fetch_user(conn) do
    conn.assigns[:user]
  end

  defp authenticate(%ApiAccounts.User{role: "administrator"}, conn), do: conn

  defp authenticate(_, conn) do
    conn
    |> put_status(:not_found)
    |> put_view(ApiWeb.ErrorView)
    |> render("404.html", [])
    |> halt()
  end
end
