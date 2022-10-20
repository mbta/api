defmodule ApiWeb.Plugs.CheckForShutdownTest do
  @moduledoc false
  use ApiWeb.ConnCase
  alias ApiWeb.Plugs.CheckForShutdown

  @opts CheckForShutdown.init([])

  setup do
    CheckForShutdown.reset()

    on_exit(&CheckForShutdown.reset/0)

    :ok
  end

  describe "call/2" do
    test "returns the conn unmodified in the default case", %{conn: conn} do
      assert CheckForShutdown.call(conn, @opts) == conn
    end

    test "returns the conn unmodified after calling started/0", %{conn: conn} do
      CheckForShutdown.started()

      assert CheckForShutdown.call(conn, @opts) == conn
    end

    test "sets Connection: close after calling shutdown/0", %{conn: conn} do
      CheckForShutdown.shutdown()

      new_conn = CheckForShutdown.call(conn, @opts)

      assert get_resp_header(new_conn, "connection") == ["close"]
    end

    test "sets Connection: close even if there's an existing keep-alive header", %{conn: conn} do
      conn = put_resp_header(conn, "connection", "keep-alive")

      CheckForShutdown.shutdown()

      new_conn = CheckForShutdown.call(conn, @opts)

      assert get_resp_header(new_conn, "connection") == ["close"]
    end
  end

  describe "running?" do
    test "defaults to true" do
      assert CheckForShutdown.running?()
    end

    test "false after calling shutdown/0" do
      CheckForShutdown.shutdown()

      refute CheckForShutdown.running?()
    end
  end
end
