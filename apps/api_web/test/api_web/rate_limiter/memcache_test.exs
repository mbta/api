defmodule ApiWeb.RateLimiter.MemcacheTest do
  use ExUnit.Case
  import ApiWeb.RateLimiter.Memcache

  @moduletag :memcache

  describe "rate_limited?/2" do
    test "returns true if there is no rate limit remaining" do
      {:ok, _} = start_link(clear_interval: 1000)
      user_id = "#{System.monotonic_time()}"
      refute rate_limited?(user_id, 1)
      assert rate_limited?(user_id, 1)
    end
  end
end
