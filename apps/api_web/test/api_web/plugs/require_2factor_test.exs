defmodule ApiWeb.Plugs.Require2FactorTest do
  use ApiWeb.ConnCase, async: true

  setup %{conn: conn} do
    conn =
      conn
      |> conn_with_session()
      |> bypass_through(ApiWeb.Router, [:browser, :admin])

    {:ok, conn: conn}
  end

  test "opts" do
    assert ApiWeb.Plugs.Require2Factor.init([]) == []
  end

  describe ":require_2factor plug" do
    test "gives 404 with no authenicated user", %{conn: conn} do
      conn = get(conn, "/")
      assert conn.status == 404
      assert html_response(conn, 404) =~ "not found"
    end

    test "gives 404 for user without administrator role", %{conn: conn} do
      conn =
        conn
        |> user_with_role(nil, true)
        |> get("/")

      assert html_response(conn, 404) =~ "not found"
    end

    test "redirects on missing 2fa, but valid admin account", %{conn: conn} do
      conn =
        conn
        |> user_with_role("administrator", false)
        |> get("/")

      assert html_response(conn, 302)
    end

    test "allows user with administrator role and 2fa to proceed", %{conn: conn} do
      conn =
        conn
        |> user_with_role("administrator", true)
        |> get("/")

      refute conn.status
    end
  end

  defp user_with_role(conn, role, totp_enabled) do
    Plug.Conn.assign(conn, :user, %ApiAccounts.User{role: role, totp_enabled: totp_enabled})
  end
end
