defmodule ApiWeb.RateLimiter.MemcacheTest do
  use ExUnit.Case
  import ApiWeb.RateLimiter.Memcache

  @moduletag :memcache

  describe "rate_limited?/2" do
    test "correctly determines whether the user is rate limited, and returns the correct number of requests" do
      {:ok, _} = start_link(clear_interval: 1000)
      user_id = "#{System.monotonic_time()}"

      assert {:remaining, 1} = rate_limited?(user_id, 2)
      assert {:remaining, 0} = rate_limited?(user_id, 2)
      assert :rate_limited == rate_limited?(user_id, 2)
    end
  end
end
