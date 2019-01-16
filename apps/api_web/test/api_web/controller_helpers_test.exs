defmodule ApiWeb.ControllerHelpersTest do
  @moduledoc false
  use ApiWeb.ConnCase, async: true
  import ApiWeb.ControllerHelpers

  describe "conn_service_date/1" do
    test "returns a service date and a conn", %{conn: conn} do
      assert {%Plug.Conn{}, %Date{}} = conn_service_date(conn)
    end

    test "caches the initial date", %{conn: conn} do
      initial_conn = conn
      {conn, date} = conn_service_date(conn)
      assert conn != initial_conn
      assert {conn, date} == conn_service_date(conn)
    end
  end
end
