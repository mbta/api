defmodule ApiWeb.EventStreamTest do
  @moduledoc false
  use ApiWeb.ConnCase
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

  describe "initialize/2" do
    test "sets the content-type to text/event-stream", %{conn: conn} do
      {conn, pid} = initialize(conn, @module)
      assert get_resp_header(conn, "content-type") == ["text/event-stream"]
      on_exit(fn -> assert_stopped(pid) end)
    end

    test "sets the x-accel-buffering header to prevent nginx from buffering", %{conn: conn} do
      {conn, pid} = initialize(conn, @module)
      assert get_resp_header(conn, "x-accel-buffering") == ["no"]
      on_exit(fn -> assert_stopped(pid) end)
    end

    test "starts the chunked response", %{conn: conn} do
      {conn, pid} = initialize(conn, @module)
      assert conn.status == 200
      assert conn.state == :chunked
      on_exit(fn -> assert_stopped(pid) end)
    end

    test "starts a server", %{conn: conn} do
      {_conn, pid} = initialize(conn, @module)
      assert is_pid(pid)
      on_exit(fn -> assert_stopped(pid) end)
    end

    test "receives events when updates happen", %{conn: conn} do
      {_conn, pid} = initialize(conn, @module)
      predictions = [%Model.Prediction{route_id: "1"}]
      State.Prediction.new_state(predictions)
      assert_receive_data()
      on_exit(fn -> assert_stopped(pid) end)
    end
  end

  describe "event_stream_loop/2" do
    test "calls next_call with the new conn if data is received", %{conn: conn} do
      {_conn, pid} = state = initialize(conn, @module)
      next_call = fn next, state -> {next, state} end

      assert {^next_call, {new_conn, ^pid}} = event_stream_loop(next_call, state)

      assert chunks(new_conn) =~ "event: reset"
      on_exit(fn -> assert_stopped(pid) end)
    end

    test "stops the server if an error is returned", %{conn: conn} do
      send(self(), {:error, ["filter_required"]})
      {conn, pid} = state = initialize(conn, @module)
      Process.unlink(pid)
      ref = Process.monitor(pid)

      assert ^conn = event_stream_loop(&event_stream_loop/2, state)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
      on_exit(fn -> assert_stopped(pid) end)
    end
  end

  describe "receive_result/1" do
    test "returns a diff when new data is returned", %{conn: conn} do
      {_conn, pid} = state = initialize(conn, @module)
      assert_receive_data()

      prediction = %Model.Prediction{route_id: "1"}

      State.Prediction.new_state([prediction])

      assert {:ok, conn} = receive_result(state)
      chunks = chunks(conn)
      assert chunks =~ "event: "
      assert chunks =~ "data: "
      assert chunks =~ "\n\n"
      on_exit(fn -> assert_stopped(pid) end)
    end

    test "returns a keepalive when nothing happens", %{conn: conn} do
      {_conn, pid} = state = initialize(conn, @module)
      assert_receive_data()
      assert {:ok, new_conn} = receive_result(state, 50)
      assert chunks(new_conn) == ": keep-alive\n"
      on_exit(fn -> assert_stopped(pid) end)
    end

    test "returns an error and closes the connection if there's a problem", %{conn: conn} do
      {_conn, pid} = state = initialize(conn, @module)
      assert_receive_data()

      send(self(), {:error, ["filter[]", " is required"]})
      assert {:error, {:ok, conn}} = receive_result(state)
      assert chunks(conn) =~ "filter[] is required"
      on_exit(fn -> assert_stopped(pid) end)
    end
  end

  defp assert_receive_data do
    assert_receive {:events, [{"reset", _}]}
  end

  defp chunks(%Plug.Conn{adapter: {_, state}}), do: state.chunks
end
