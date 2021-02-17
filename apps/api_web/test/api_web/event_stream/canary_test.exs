defmodule ApiWeb.EventStream.CanaryTest do
  use ExUnit.Case, async: true

  alias ApiWeb.EventStream.Canary

  test "calls the provided function when terminated with reason :shutdown" do
    test_pid = self()
    {:ok, canary} = GenServer.start(Canary, fn -> send(test_pid, :notified) end)
    refute_receive :notified

    GenServer.stop(canary, :shutdown)
    assert_receive :notified
  end

  test "does nothing when terminated with a reason other than :shutdown" do
    test_pid = self()
    {:ok, canary} = GenServer.start(Canary, fn -> send(test_pid, :notified) end)

    GenServer.stop(canary)
    refute_receive :notified
  end
end
