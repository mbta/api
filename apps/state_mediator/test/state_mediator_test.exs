defmodule StateMediatorTest do
  use ExUnit.Case

  describe "source_url/1" do
    test "returns default config value when no environment variable set" do
      assert StateMediator.source_url(State.FakeModuleA) == "default_a"
    end

    test "returns environment value when set set" do
      expected = "config_b"
      :os.putenv(~c"FAKE_VAR_B", String.to_charlist(expected))
      assert StateMediator.source_url(State.FakeModuleB) == expected
    end

    test "returns config value when explicitly set" do
      assert StateMediator.source_url(State.FakeModuleC) == "default_c"
    end
  end
end
