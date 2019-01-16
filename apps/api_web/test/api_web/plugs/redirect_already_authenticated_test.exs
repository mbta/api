defmodule ApiWeb.Plugs.RedirectAlreadyAuthenticatedTest do
  use ApiWeb.ConnCase, async: true

  test "init" do
    assert ApiWeb.Plugs.RedirectAlreadyAuthenticated.init([]) == []
  end

  setup %{conn: conn} do
    conn =
      conn
      |> conn_with_session()
      |> bypass_through(ApiWeb.Router, [:browser])

    {:ok, %{conn: conn}}
  end

  test "redirects when user already authenticated", %{conn: conn} do
    conn =
      conn
      |> assign(:user, %ApiAccounts.User{})
      |> get("/")
      |> ApiWeb.Plugs.RedirectAlreadyAuthenticated.call([])

    assert redirected_to(conn) == portal_path(conn, :index)
    assert conn.halted
  end

  test "does not redirect when user isn't authenticated", %{conn: conn} do
    conn =
      conn
      |> get("/")
      |> ApiWeb.Plugs.RedirectAlreadyAuthenticated.call([])

    refute conn.status
    refute conn.halted
  end
end
