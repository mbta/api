defmodule ApiWebTest do
  @moduledoc false
  use ExUnit.Case
  doctest ApiWeb

  describe "runtime_config!/0" do
    setup do
      old_env = Application.get_env(:api_web, :api_pipeline)

      on_exit(fn ->
        Application.put_env(:api_web, :api_pipeline, old_env)
      end)

      :ok
    end
  end

  test "config/1 returns configuration" do
    assert Keyword.keyword?(ApiWeb.config(ApiWeb.Endpoint))
  end

  test "config/1 raises when key is missing" do
    assert_raise ArgumentError, fn -> ApiWeb.config(:not_exists) end
  end

  test "config/2 returns configuration" do
    assert is_list(ApiWeb.config(ApiWeb.Endpoint, :url))
  end

  test "config/2 raises when key is missing" do
    assert_raise RuntimeError, fn -> ApiWeb.config(ApiWeb.Endpoint, :not_exists) end
  end
end
