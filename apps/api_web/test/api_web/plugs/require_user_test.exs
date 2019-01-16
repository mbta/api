defmodule ApiWeb.Plugs.RequireUserTest do
  use ApiWeb.ConnCase, async: true

  test "init" do
    opts = []
    assert ApiWeb.Plugs.RequireUser.init(opts) == opts
  end

  test "proceeds if user present", %{conn: conn} do
    conn =
      conn
      |> assign(:user, %ApiAccounts.User{})
      |> ApiWeb.Plugs.RequireUser.call([])

    refute conn.status
    refute conn.halted
  end

  test "redirect to login if user isn't present", %{conn: conn} do
    conn = ApiWeb.Plugs.RequireUser.call(conn, [])
    assert redirected_to(conn) == session_path(conn, :new)
    assert conn.halted
  end
end
