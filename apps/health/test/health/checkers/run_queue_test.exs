defmodule Health.Checkers.RunQueueTest do
  use ExUnit.Case
  import Health.Checkers.RunQueue

  describe "healthy?/0" do
    test "always returns true" do
      assert healthy?() == true
    end
  end

  describe "current/0" do
    test "returns the current run queue size" do
      [run_queue: size] = current()
      assert is_integer(size)
      assert size >= 0
    end
  end
end
