defmodule RequestTrackTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import RequestTrack

  setup do
    {:ok, pid} = start_link()
    {:ok, %{pid: pid}}
  end

  describe "increment/2" do
    test "increases the count for the provided key", %{pid: pid} do
      :ok = increment(pid, :key)
      assert count(pid, :key) == 1
      :ok = increment(pid, :key)
      assert count(pid, :key) == 2
    end

    test "does not increase the count for other keys", %{pid: pid} do
      :ok = increment(pid, :key)
      assert count(pid, :other_key) == 0
    end

    test "multiple processes can increment the same key", %{pid: pid} do
      :ok = increment(pid, :key)
      {:ok, _agent} = Agent.start_link(fn -> increment(pid, :key) end)
      assert count(pid, :key) == 2
    end
  end

  describe "decrement/1" do
    test "removes any items for the current process", %{pid: pid} do
      :ok = increment(pid, :key)
      :ok = increment(pid, :other)
      :ok = decrement(pid)
      assert count(pid, :key) == 0
      assert count(pid, :other_key) == 0
    end

    test "decrementing without incrementing does not return a negative value", %{pid: pid} do
      :ok = decrement(pid)
      assert count(pid, :key) == 0
    end
  end

  describe "monitoring" do
    test "a process which stops removes all incremented values", %{pid: pid} do
      {:ok, agent} = Agent.start_link(fn -> increment(pid, :key) end)
      assert count(pid, :key) == 1
      Agent.stop(agent)
      assert await_count(pid, :key, 0) == :ok
    end

    defp await_count(pid, key, expected, retries \\ 5)

    defp await_count(_, _, _, 0) do
      :error
    end

    defp await_count(pid, key, expected, retries) do
      if count(pid, key) == expected do
        :ok
      else
        Process.sleep(100)
        await_count(pid, key, expected, retries - 1)
      end
    end
  end

  describe "handle_info(DOWN)" do
    test "if the ref does not match our monitor, it's ignored" do
      {:ok, pid} = Agent.start_link(fn -> :ok end)
      bad_ref = make_ref()

      {:ok, state} = init([])
      {:noreply, state} = handle_cast({:monitor, pid}, state)
      {:noreply, new_state} = handle_info({:DOWN, bad_ref, :process, pid, :normal}, state)
      assert state == new_state
    end
  end
end
