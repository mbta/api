defmodule ApiWeb.EventStream.SupervisorTest do
  @moduledoc false
  use ApiWeb.ConnCase
  import ApiWeb.EventStream.Supervisor
  import ApiWeb.Test.ProcessHelper
  alias ApiWeb.RouteController

  setup %{conn: conn} do
    conn = get(conn, "/routes")
    {:ok, %{conn: conn}}
  end

  describe "server_subscribe/2" do
    test "subscribes the current process to events and returns {:ok, pid}", %{conn: conn} do
      assert {:ok, pid} = server_subscribe(conn, RouteController)
      assert is_pid(pid)
      assert_receive {:events, [{"reset", _}]}
    end

    test "returns the same pid if a server already exists for the given args", %{conn: conn} do
      assert {:ok, pid} = server_subscribe(conn, RouteController)
      {:ok, agent} = Agent.start_link(fn -> :ok end)

      conn = %{conn | query_params: %{"api_key" => "key"}}
      assert {:ok, ^pid} = Agent.get(agent, fn _ -> server_subscribe(conn, RouteController) end)
    end
  end

  describe "server_unsubscribe/1" do
    test "server stops when clients have unsubscribed", %{conn: conn} do
      {:ok, pid} = server_subscribe(conn, RouteController)
      :ok = server_unsubscribe(pid)
      assert_stopped(pid)
    end
  end

  describe "terminate_servers/0" do
    test "terminates all servers", %{conn: conn} do
      {:ok, pid} = server_subscribe(conn, RouteController)
      :ok = terminate_servers()
      assert_stopped(pid)
    end
  end
end
