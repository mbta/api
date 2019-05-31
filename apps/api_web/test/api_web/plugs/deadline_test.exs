defmodule ApiWeb.Plugs.DeadlineTest do
  @moduledoc false
  use ApiWeb.ConnCase, async: true
  import ApiWeb.Plugs.Deadline

  setup %{conn: conn} do
    conn = call(conn, init([]))
    {:ok, %{conn: conn}}
  end

  describe "check!/1" do
    test "returns :ok if the deadline is met", %{conn: conn} do
      assert :ok =
               conn
               |> set(5_000)
               |> check!
    end

    test "returns :ok if no deadline was set", %{conn: conn} do
      assert :ok = check!(conn)
    end

    test "raises an exception if the deadline is missed", %{conn: conn} do
      conn = set(conn, -1)

      assert_raise ApiWeb.Plugs.Deadline.Error, fn ->
        check!(conn)
      end
    end
  end
end
