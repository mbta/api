defmodule StateMediator.S3MediatorTest do
  use ExUnit.Case, async: true

  import StateMediator.S3Mediator

  defmodule StateModule do
    def size do
      0
    end

    def new_state(pid, _timeout) do
      send(pid, :received_new_state)
    end
  end

  @moduletag capture_log: true
  @opts [
    bucket_arn: "mbta-gtfs-boom-shakalaka",
    object: "objection",
    state: __MODULE__.StateModule,
    interval: 1_000
  ]

  describe "init/1" do
    test "sends self() the :initial message" do
      assert {:ok, _} = init(@opts)
      assert_received :initial
    end

    test "builds an initial state" do
      assert {:ok, state} = init(@opts)
      assert %StateMediator.S3Mediator{} = state
      assert state.module == @opts[:state]
      assert state.bucket_arn == @opts[:bucket_arn]
      assert state.sync_timeout == 5_000
      assert state.interval == 1_000
    end
  end

  describe "handle_response/2" do
    test "on body: schedules an update" do
      {:ok, state} = init(@opts)
      assert {:noreply, state, 1_000} = handle_response({:ok, self()}, state)
    end

    test "on error: schedules an update" do
      {:ok, state} = init(@opts)
      assert {:noreply, state, 1_000} = handle_response({:error, "error"}, state)
    end
  end
end
