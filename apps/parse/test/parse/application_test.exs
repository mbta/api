defmodule Parse.ApplicationTest do
  @moduledoc false
  use ExUnit.Case

  describe "start/2" do
    setup do
      :ok = Application.stop(:parse)

      on_exit(fn ->
        Application.ensure_all_started(:parse)
      end)

      :ok
    end

    test "starts the application" do
      assert Application.start(:parse, :transient) == :ok
    end
  end
end
