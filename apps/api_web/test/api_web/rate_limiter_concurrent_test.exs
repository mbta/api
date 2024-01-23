defmodule ApiWeb.RateLimiterConcurrentTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use Plug.Test
  alias ApiWeb.RateLimiter.RateLimiterConcurrent

  test "start_link/1" do
    Application.stop(:api_web)

    on_exit(fn ->
      Application.start(:api_web)
    end)

    assert {:ok, _pid} = RateLimiterConcurrent.start_link([])
  end

  test "check_concurrent_rate_limit/1" do
    {anon_streaming_at_limit?, anon_streaming_remaining, anon_streaming_limit} =
      RateLimiterConcurrent.check_concurrent_rate_limit(%ApiWeb.User{type: :anon}, true)

    assert anon_streaming_limit == ApiWeb.config(:rate_limiter_concurrent, :max_anon_streaming)
    assert anon_streaming_remaining == anon_streaming_limit
    assert anon_streaming_at_limit? == false

    {anon_static_at_limit?, anon_static_remaining, anon_static_limit} =
      RateLimiterConcurrent.check_concurrent_rate_limit(%ApiWeb.User{type: :anon}, false)

    assert anon_static_limit == ApiWeb.config(:rate_limiter_concurrent, :max_anon_static)
    assert anon_static_remaining == anon_static_limit
    assert anon_static_at_limit? == false

    {registered_streaming_at_limit?, registered_streaming_remaining, registered_streaming_limit} =
      RateLimiterConcurrent.check_concurrent_rate_limit(%ApiWeb.User{type: :registered}, true)

    assert registered_streaming_limit ==
             ApiWeb.config(:rate_limiter_concurrent, :max_registered_streaming)

    assert registered_streaming_remaining == registered_streaming_limit
    assert registered_streaming_at_limit? == false

    {registered_static_at_limit?, registered_static_remaining, registered_static_limit} =
      RateLimiterConcurrent.check_concurrent_rate_limit(%ApiWeb.User{type: :registered}, false)

    assert registered_static_limit ==
             ApiWeb.config(:rate_limiter_concurrent, :max_registered_static)

    assert registered_static_remaining == registered_static_limit
    assert registered_static_at_limit? == false
  end
end
