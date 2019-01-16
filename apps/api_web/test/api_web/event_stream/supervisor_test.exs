defmodule ApiWeb.EventStream.SupervisorTest do
  @moduledoc false
  use ApiWeb.ConnCase
  import ApiWeb.EventStream.Supervisor
  import ApiWeb.Test.ProcessHelper

  describe "server_child/2" do
    setup %{conn: conn} do
      conn = get(conn, "/routes")
      {:ok, %{conn: conn}}
    end

    test "returns an {:ok, pid} tuple", %{conn: conn} do
      assert {:ok, pid} = server_child(conn, ApiWeb.RouteController)
      assert is_pid(pid)
      assert_receive {:events, [{"reset", _}]}
    end

    @tag :capture_log
    test "returns the same {:ok, pid} tuple if it already exists", %{conn: conn} do
      assert {:ok, pid} = server_child(conn, ApiWeb.RouteController)
      {:ok, agent} = Agent.start_link(fn -> :ok end)

      conn = %{conn | query_params: %{"api_key" => "key"}}

      assert {:ok, ^pid} =
               Agent.get(agent, fn _ -> server_child(conn, ApiWeb.RouteController) end)
    end

    @tag :capture_log
    test "server stops when clients have unsubscribed", %{conn: conn} do
      {:ok, pid} = server_child(conn, ApiWeb.RouteController)
      :ok = server_unsubscribe(pid)
      assert_stopped(pid)
    end
  end
end
