defmodule Events.GatherTest do
  use ExUnit.Case, async: true
  alias Events.Gather

  def received_ok? do
    receive do
      :ok -> true
    after
      10 -> false
    end
  end

  test "gather calls callback when all keys are present" do
    keys = [1, 2]
    state = Gather.new(keys, fn %{1 => :one, 2 => :two} -> send(self(), :ok) end)
    refute_receive :ok
    state = Gather.update(state, 1, :one)
    refute_receive :ok
    state = Gather.update(state, 2, :two)
    assert_receive :ok

    # does not re-call the callback
    Gather.update(state, 1, :one)
    assert_receive :ok
  end

  test "only remembers the last value sent" do
    keys = [1, 2]
    state = Gather.new(keys, fn %{1 => :one, 2 => :two} -> send(self(), :ok) end)
    state = Gather.update(state, 1, :other)
    state = Gather.update(state, 1, :one)
    Gather.update(state, 2, :two)
    assert_receive :ok
  end
end
