defmodule ApiWeb.RateLimiter.MemcacheTest do
  use ExUnit.Case
  import ApiWeb.RateLimiter.Memcache

  @moduletag :memcache

  describe "rate_limited?/2" do
    test "returns true if there is no rate limit remaining" do
      {:ok, _} = start_link(clear_interval: 1000)
      user_id = "#{System.monotonic_time()}"

      {has_limit, _} = rate_limited?(user_id, 1)
      refute has_limit

      {has_limit, _} = rate_limited?(user_id, 1)
      assert has_limit
    end

    test "returns the correct number of requests" do
      {:ok, _} = start_link(clear_interval: 1000)
      user_id = "#{System.monotonic_time()}"

      {_, requests} = rate_limited?(user_id, 2)
      assert requests == 1

      {_, requests} = rate_limited?(user_id, 2)
      assert requests == 2

      {_, requests} = rate_limited?(user_id, 2)
      assert requests == 2
    end
  end
end
