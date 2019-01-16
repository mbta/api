defmodule ApiWeb.Plugs.RequireAdminTest do
  use ApiWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn =
      conn
      |> conn_with_session()
      |> bypass_through(ApiWeb.Router, [:browser, :admin])

    {:ok, conn: conn}
  end

  test "opts" do
    assert ApiWeb.Plugs.RequireAdmin.init([]) == []
  end

  describe ":require_admin plug" do
    test "gives 404 with no authenicated user", %{conn: conn} do
      conn = get(conn, "/")
      assert conn.status == 404
      assert html_response(conn, 404) =~ "not found"
    end

    test "gives 404 for user without administrator role", %{conn: conn} do
      conn =
        conn
        |> user_with_role(nil)
        |> get("/")

      assert html_response(conn, 404) =~ "not found"
    end

    test "allows user with administrator role to proceed", %{conn: conn} do
      conn =
        conn
        |> user_with_role("administrator")
        |> get("/")

      refute conn.status
    end
  end

  defp user_with_role(conn, role) do
    Plug.Conn.assign(conn, :user, %ApiAccounts.User{role: role})
  end
end
