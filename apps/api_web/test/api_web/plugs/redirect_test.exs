defmodule ApiWeb.Plugs.RedirectTest do
  use ApiWeb.ConnCase
  alias ApiWeb.Plugs.Redirect

  test "init/1" do
    assert Redirect.init([]) == []
  end

  test "call/2", %{conn: conn} do
    conn =
      conn
      |> bypass_through()
      |> get("/")
      |> Redirect.call(to: "/test")

    assert redirected_to(conn) == "/test"
    assert conn.halted
  end
end
