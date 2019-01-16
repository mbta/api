defmodule Fetch.FileTapTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Fetch.FileTap

  describe "start_link/0" do
    test "starts the process" do
      assert {:ok, _pid} = start_link([])
    end
  end

  describe "init/1" do
    test "returns a map with module/max_tap_size" do
      assert {:ok, %{module: :mod, max_tap_size: 10}} = init(module: :mod, max_tap_size: 10)
      assert {:ok, %{module: :mod, max_tap_size: :infinity}} = init(module: :mod)
    end

    test "returns an empty map if no module is configured" do
      assert {:ok, %{}} = init([])
    end
  end
end
