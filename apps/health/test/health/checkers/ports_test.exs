defmodule Health.Checkers.PortsTest do
  use ExUnit.Case
  alias Health.Checkers.Ports

  describe "current/0" do
    test "returns an integer number of ports" do
      kw = Ports.current()
      assert kw[:ports] >= 0
    end
  end

  describe "healthy?" do
    test "true if the number of ports is low" do
      assert Ports.healthy?()
    end

    test "false if the number of ports is higher than the configuration" do
      old = Application.get_env(:health, Ports)

      on_exit(fn ->
        Application.put_env(:health, Ports, old)
      end)

      Application.put_env(:health, Ports, max_ports: -1)

      refute Ports.healthy?()
    end
  end
end
