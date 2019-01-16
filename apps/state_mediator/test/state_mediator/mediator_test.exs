defmodule StateMediator.MediatorTest do
  use ExUnit.Case, async: true

  import StateMediator.Mediator

  defmodule StateModule do
    def size do
      0
    end

    def new_state(pid, _timeout) do
      send(pid, :received_new_state)
    end
  end

  @moduletag capture_log: true
  @opts [url: "http://localhost", state: __MODULE__.StateModule, interval: 30_000]

  describe "init/1" do
    test "sends self() the :initial message" do
      assert {:ok, _} = init(@opts)
      assert_received :initial
    end

    test "builds an initial state" do
      assert {:ok, state} = init(@opts)
      assert %StateMediator.Mediator{} = state
      assert state.module == @opts[:state]
      assert state.url == @opts[:url]
      assert state.sync_timeout == 5_000
      assert state.interval == 30_000
    end

    test "ignores the server with an empty URL" do
      assert :ignore = init(url: "", state: __MODULE__.StateModule, interval: 30_000)
    end
  end

  describe "handle_response/2" do
    test "on body: resets retries and schedules an update" do
      {:ok, state} = init(@opts)
      {:noreply, state, _} = handle_response({:error, "error"}, state)
      assert {:noreply, state, 30_000} = handle_response({:ok, self()}, state)
      assert_received :received_new_state
      assert state.retries == 0
    end

    test "on unmodified: resets retries and schedules an update" do
      {:ok, state} = init(@opts)
      {:noreply, state, _} = handle_response({:error, "error"}, state)
      assert {:noreply, state, 30_000} = handle_response(:unmodified, state)
      refute_received :received_new_state
      assert state.retries == 0
    end

    test "on error: increments retries and times out" do
      {:ok, state} = init(@opts)
      assert {:noreply, state, timeout} = handle_response({:error, "error"}, state)
      assert state.retries == 1
      assert timeout >= 1_000
      assert timeout <= 3_000
      # another timeout
      assert {:noreply, state, timeout} = handle_response({:error, "error"}, state)
      assert state.retries == 2
      assert timeout >= 1_000
      assert timeout <= 5_000
    end
  end
end
