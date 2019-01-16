defmodule ApiWeb.Plugs.RedirectAlreadyAuthenticated do
  @moduledoc """
  Redirects to Client Portal index page when user is already authenticated.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(conn, _) do
    case conn.assigns[:user] do
      %ApiAccounts.User{} ->
        conn
        |> redirect(to: ApiWeb.Router.Helpers.portal_path(conn, :index))
        |> halt()

      _ ->
        conn
    end
  end
end
