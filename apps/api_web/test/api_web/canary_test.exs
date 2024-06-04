defmodule ApiWeb.CanaryTest do
  use ExUnit.Case, async: true

  alias ApiWeb.Canary

  test "calls the provided function when terminated with reason :shutdown" do
    test_pid = self()
    {:ok, canary} = GenServer.start(Canary, fn -> send(test_pid, :notified) end)
    refute_receive :notified

    GenServer.stop(canary, :shutdown)
    assert_receive :notified
  end

  test "calls the provided function when terminated with reason :normal" do
    test_pid = self()
    {:ok, canary} = GenServer.start(Canary, fn -> send(test_pid, :notified) end)
    refute_receive :notified

    GenServer.stop(canary, :shutdown)
    assert_receive :notified
  end

  @tag :capture_log
  test "does nothing when terminated with a reason other than :shutdown or :normal" do
    test_pid = self()
    {:ok, canary} = GenServer.start(Canary, fn -> send(test_pid, :notified) end)

    GenServer.stop(canary, :unexpected)
    refute_receive :notified
  end

  test "default notify function is set if function is not provided" do
    Process.flag(:trap_exit, true)
    pid = spawn_link(Canary, :start_link, [])

    assert_receive {:EXIT, ^pid, :normal}
  end

  test "stops with reason if given a value that is not a function for notify_fn" do
    Process.flag(:trap_exit, true)

    assert {:error, "expect function/0 for notify_fn, got nil"} =
             Canary.start_link(notify_fn: nil)

    # start_link consumes EXIT as of OTP 26, so we need to use spawn_link to trigger this. see:
    # https://github.com/erlang/otp/issues/7524 and
    # https://www.erlang.org/doc/apps/stdlib/gen_server.html#start_link/4
    pid = spawn_link(Canary, :start_link, [[notify_fn: nil]])

    assert_receive {:EXIT, ^pid, "expect function/0 for notify_fn, got nil"}
  end
end
