defmodule ApiWeb.Plugs.RequireUser do
  @moduledoc """
  Requires a user to be assigned to the Conn.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]
  def init(opts), do: opts

  def call(conn, _) do
    case conn.assigns[:user] do
      %ApiAccounts.User{} ->
        conn

      nil ->
        conn
        |> redirect(to: ApiWeb.Router.Helpers.session_path(conn, :new))
        |> halt()
    end
  end
end
