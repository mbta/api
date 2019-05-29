defmodule Health.Checkers.RunQueueTest do
  use ExUnit.Case
  import Health.Checkers.RunQueue

  describe "log_processes/2" do
    test "logs if we're not healthy and the log level is low enough" do
      assert log_processes(false, :info) == :logged
      assert log_processes(false, :debug) == :logged
    end

    test "does nothing when we're healthy" do
      assert log_processes(true, :info) == :ignored
    end

    test "does nothing when the log level is high" do
      assert log_processes(false, :warn) == :ignored
    end
  end

  describe "log_lines/0" do
    test "one line per process" do
      lines = log_lines()
      assert length(lines) == length(Process.list())
    end
  end

  describe "log_info/1" do
    test "logs information about the process" do
      binary = IO.iodata_to_binary(log_info(self()))
      assert binary =~ ~s(current_function="Elixir.Process.info/2")
      assert binary =~ ~s(initial_call="erlang.apply/2")
      assert binary =~ ~s(message_queue_len=0)
      assert binary =~ ~s(status=running)
    end

    test "overrides initial call if present in process dictionary" do
      # GenServers set this
      {:ok, pid} = Agent.start_link(fn -> :ok end)
      binary = IO.iodata_to_binary(log_info(pid))

      assert binary =~
               ~s(initial_call="Elixir.Health.Checkers.RunQueueTest.-test log_info/1 overrides initial call if present in process dictionary/1-fun-0-/0")
    end

    test "logs a dead process" do
      {:ok, pid} = Agent.start_link(fn -> :ok end)
      Agent.stop(pid)
      binary = IO.iodata_to_binary(log_info(pid))
      assert binary =~ ~s(status=dead)
    end
  end
end
