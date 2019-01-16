defmodule Health.CheckerTest do
  use ExUnit.Case, async: true
  import Health.Checker

  describe "current/0" do
    test "returns a non empty keyword list" do
      actual = current()
      assert Keyword.keyword?(actual)
      refute actual == []
    end
  end

  describe "healthy?" do
    test "returns a boolean" do
      assert is_boolean(healthy?())
    end
  end
end
