defmodule ApiWeb.EventStreamTest do
  @moduledoc false
  use ApiWeb.ConnCase
  alias ApiWeb.EventStream.{Canary, ServerSupervisor}
  import ApiWeb.EventStream
  import Plug.Conn
  import ApiWeb.Test.ProcessHelper

  @module ApiWeb.PredictionController

  @moduletag timeout: 5_000

  setup %{conn: conn} do
    State.Prediction.new_state([])

    conn =
      conn
      |> put_private(:phoenix_view, ApiWeb.PredictionView)
      |> Map.put(:params, %{"route" => "1"})

    {:ok, %{conn: conn}}
  end

  describe "call/3" do
    test "hibernates after receiving a message", %{conn: conn} do
      {:ok, pid} = Agent.start_link(fn -> conn end)
      :ok = Agent.cast(pid, fn conn -> call(conn, @module, %{}) end)
      assert :ok = await_hibernate(pid, 10)
    end
  end

  describe "initialize/2" do
    test "sets the content-type to text/event-stream", %{conn: conn} do
      state = initialize(conn, @module)
      assert get_resp_header(state.conn, "content-type") == ["text/event-stream"]
      on_exit(fn -> assert_stopped(state.pid) end)
    end

    test "sets the x-accel-buffering header to prevent nginx from buffering", %{conn: conn} do
      state = initialize(conn, @module)
      assert get_resp_header(state.conn, "x-accel-buffering") == ["no"]
      on_exit(fn -> assert_stopped(state.pid) end)
    end

    test "starts the chunked response", %{conn: conn} do
      state = initialize(conn, @module)
      assert state.conn.status == 200
      assert state.conn.state == :chunked
      on_exit(fn -> assert_stopped(state.pid) end)
    end

    test "starts a server", %{conn: conn} do
      state = initialize(conn, @module)
      assert is_pid(state.pid)
      on_exit(fn -> assert_stopped(state.pid) end)
    end

    test "receives events when updates happen", %{conn: conn} do
      state = initialize(conn, @module)
      predictions = [%Model.Prediction{route_id: "1"}]
      State.Prediction.new_state(predictions)
      assert_receive_data()
      on_exit(fn -> assert_stopped(state.pid) end)
    end
  end

  describe "receive_result/1" do
    test "returns a diff when new data is returned", %{conn: conn} do
      state = initialize(conn, @module)
      assert_receive_data()

      prediction = %Model.Prediction{route_id: "1"}

      State.Prediction.new_state([prediction])

      assert {:continue, state} = receive_result(state)
      chunks = chunks(state.conn)
      assert chunks =~ "event: "
      assert chunks =~ "data: "
      assert chunks =~ "\n\n"
      on_exit(fn -> assert_stopped(state.pid) end)
    end

    test "returns a keepalive when nothing happens", %{conn: conn} do
      state = initialize(conn, @module, 50)
      assert_receive_data()
      assert {:continue, state} = receive_result(state)
      assert chunks(state.conn) == ": keep-alive\n"
      on_exit(fn -> assert_stopped(state.pid) end)
    end

    test "returns an error and closes the connection if there's a problem", %{conn: conn} do
      state = initialize(conn, @module)
      assert_receive_data()

      send(self(), {:error, ["filter[]", " is required"]})
      assert {:close, conn} = receive_result(state)
      assert chunks(conn) =~ "filter[] is required"
      on_exit(fn -> assert_stopped(state.pid) end)
    end

    test "closes the connection when its diff server exits normally", %{conn: conn} do
      state = initialize(conn, @module)
      %{pid: diff_server_pid} = state
      assert_receive_data()

      :ok = DynamicSupervisor.terminate_child(ServerSupervisor, diff_server_pid)
      assert {:close, conn} = receive_result(state)
      assert chunks(conn) == ""
      on_exit(fn -> assert_stopped(state.pid) end)
    end

    test "returns an error and closes the connection if its diff server crashes", %{conn: conn} do
      state = initialize(conn, @module)
      %{pid: diff_server_pid} = state
      assert_receive_data()

      Process.exit(diff_server_pid, :kill)
      assert {:close, conn} = receive_result(state)
      assert chunks(conn) =~ "internal_error"
      on_exit(fn -> assert_stopped(state.pid) end)
    end

    test "closes the connection when the Canary is shut down", %{conn: conn} do
      # prevent the test process from exiting when we terminate the Canary
      Process.flag(:trap_exit, true)
      state = initialize(conn, @module)
      {:ok, canary} = Canary.start_link()
      assert_receive_data()

      GenServer.stop(canary, :shutdown)
      assert {:close, conn} = receive_result(state)
      assert chunks(conn) == ""
      on_exit(fn -> assert_stopped(state.pid) end)
    end
  end

  describe "hibernate_loop/1" do
    test "returns the final conn and unsubscribes if it receives an error", %{conn: conn} do
      state = initialize(conn, @module)
      assert_receive_data()

      pid = state.pid
      ref = Process.monitor(state.pid)

      send(self(), {:error, ["got an error"]})

      assert %Plug.Conn{state: :chunked} = hibernate_loop(state)

      # unsubscribed process is terminated
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    end
  end

  defp assert_receive_data do
    assert_receive {:events, [{"reset", _}]}
    assert_receive {:plug_conn, :sent}
  end

  defp chunks(%Plug.Conn{adapter: {_, state}}), do: state.chunks

  defp await_hibernate(pid, count) when count > 0 do
    info = :erlang.process_info(pid, :current_function)

    if info == {:current_function, {:erlang, :hibernate, 3}} do
      :ok
    else
      Process.sleep(100)
      await_hibernate(pid, count - 1)
    end
  end

  defp await_hibernate(_pid, _count), do: :failed
end
