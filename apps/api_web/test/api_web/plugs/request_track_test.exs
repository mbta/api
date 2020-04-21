defmodule ApiWeb.Plugs.RequestTrackTest do
  @moduledoc false
  use ApiWeb.ConnCase, async: true
  import ApiWeb.Plugs.RequestTrack
  import Plug.Conn

  setup %{conn: conn} do
    api_key = String.duplicate("v", 32)

    {:ok, name} = RequestTrack.start_link()
    opts = init(name: name)

    conn = assign(conn, :api_user, api_key)

    {:ok, %{opts: opts, conn: conn, name: name}}
  end

  describe "call/2" do
    test "increments the count before sending, decrements after", %{
      conn: conn,
      opts: opts,
      name: name
    } do
      conn = call(conn, opts)
      assert_request_count(name, conn.assigns.api_user, 1)

      conn = send_resp(conn, 200, "")
      assert_request_count(name, conn.assigns.api_user, 0)
    end

    test "decrements the count even if halt/1 is used", %{conn: conn, opts: opts, name: name} do
      conn =
        conn
        |> call(opts)
        |> halt()
        |> send_resp(200, "")

      assert_request_count(name, conn.assigns.api_user, 0)
    end

    test "does not decrement the count if set_chunked is used", %{
      conn: conn,
      opts: opts,
      name: name
    } do
      conn =
        conn
        |> call(opts)
        |> halt()
        |> send_chunked(200)

      assert_request_count(name, conn.assigns.api_user, 1)
    end

    test "decrements the count after set_chunked when the process exits", %{
      conn: conn,
      opts: opts,
      name: name
    } do
      {:ok, pid} = Agent.start_link(fn -> conn end)
      _ = Agent.update(pid, fn conn -> call(conn, opts) end)
      assert_request_count(name, conn.assigns.api_user, 1)

      _ = Agent.update(pid, fn conn -> send_chunked(conn, 200) end)
      assert_request_count(name, conn.assigns.api_user, 1)

      :ok = Agent.stop(pid)
      assert_request_count(name, conn.assigns.api_user, 0)
    end
  end

  defp assert_request_count(name, key, count) do
    {[], result} =
      Enum.flat_map_reduce(0..5, :error, fn _, _ ->
        if RequestTrack.count(name, key) == count do
          {:halt, :ok}
        else
          Process.sleep(100)
          {[], :error}
        end
      end)

    if result == :ok do
      result
    else
      actual_count = RequestTrack.count(name, key)
      flunk("failed to have the correct count: #{actual_count} != #{count}")
    end
  end
end
