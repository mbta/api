defmodule StateMediator.S3MediatorTest do
  use ExUnit.Case, async: true

  import Mox
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
    test "fires a continue" do
      assert {:ok, _, {:continue, _}} = init(@opts)
    end

    test "builds an initial state" do
      assert {:ok, state, {:continue, _}} = init(@opts)
      assert %StateMediator.S3Mediator{} = state
      assert state.module == @opts[:state]
      assert state.bucket_arn == @opts[:bucket_arn]
      assert state.sync_timeout == 5_000
      assert state.interval == 1_000
    end
  end

  describe "handle_info/2" do
    test "on body: schedules an update" do
      {:ok, state, {:continue, _}} = init(@opts)
      assert {:noreply, ^state, 1_000} = handle_info(:timeout, state)
    end

    test "on error: schedules an update" do
      {:ok, state, {:continue, _}} = init(@opts)
      Mox.defmock(FakeAws, for: ExAws.Behaviour)

      test_pid = self()
      monitor_pid = GenServer.whereis(StateMediator.S3Mediator)
      allow(FakeAws, test_pid, monitor_pid)
      stub(FakeAws, :request, fn _ -> {:error, %{body: "your transit isn't rapid enough"}} end)

      assert {:noreply, ^state, 1_000} = handle_info(:timeout, state)
    end
  end
end
