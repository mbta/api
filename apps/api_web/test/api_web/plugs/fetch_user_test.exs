defmodule ApiWeb.Plugs.FetchUserTest do
  use ApiWeb.ConnCase, async: false

  test "init" do
    opts = []
    assert ApiWeb.Plugs.FetchUser.init(opts) == opts
  end

  setup %{conn: conn} do
    ApiAccounts.Dynamo.create_table(ApiAccounts.User)
    on_exit(fn -> ApiAccounts.Dynamo.delete_all_tables() end)
    {:ok, user} = ApiAccounts.create_user(%{email: "test@mbta.com"})

    conn =
      conn
      |> conn_with_session()
      |> bypass_through(ApiWeb.Router, [:browser])

    {:ok, %{conn: conn, user: user}}
  end

  test "fetches user when id present in session", %{conn: conn, user: user} do
    conn =
      conn
      |> Plug.Conn.put_session(:user_id, user.id)
      |> ApiWeb.Plugs.FetchUser.call([])

    assert conn.assigns.user == user
  end

  test "doesn't assign when no user id in session", %{conn: conn} do
    conn = ApiWeb.Plugs.FetchUser.call(conn, [])
    refute conn.assigns[:user]
  end
end
