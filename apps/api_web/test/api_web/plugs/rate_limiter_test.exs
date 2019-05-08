defmodule ApiWeb.Plugs.RateLimiterTest do
  use ApiWeb.ConnCase, async: false

  @url "/stops/"

  defp simulate_max_anon_requests do
    # Wait for clear if we're close to clearing the rate limit.
    # This avoids spurious test failures due to the limit clearing in the middle of our requests.
    interval_ms = ApiWeb.config(:rate_limiter, :clear_interval)
    remaining_ms = rem(System.system_time(:millisecond), interval_ms)
    clear_ms = interval_ms - remaining_ms

    if clear_ms < interval_ms / 2 do
      Process.sleep(clear_ms + div(interval_ms, 10))
    end

    for _ <- 1..ApiWeb.config(:rate_limiter, :max_anon_per_interval) do
      assert get(build_conn(), @url).status == 200
    end
  end

  test "opts" do
    assert ApiWeb.Plugs.RateLimiter.init([]) == []
  end

  describe "requests with no api key" do
    setup %{conn: conn} do
      conn = assign(conn, :api_key, nil)
      ApiWeb.RateLimiter.force_clear()
      {:ok, conn: conn}
    end

    test "assigns anonymous user", %{conn: conn} do
      conn = get(conn, @url)
      assert %ApiWeb.User{type: :anon} = conn.assigns.api_user
    end

    test "rate limits anonymous requests", %{conn: conn} do
      simulate_max_anon_requests()
      assert get(conn, @url).status == 429
    end
  end

  describe "requests with valid key" do
    setup %{conn: conn} do
      ApiWeb.RateLimiter.force_clear()
      {:ok, conn: conn}
    end

    test "does not rate limit requests at anon rate", %{conn: conn} do
      simulate_max_anon_requests()
      assert get(conn, @url).status == 200
    end
  end

  describe "requests with invalid key" do
    setup %{conn: conn} do
      conn =
        conn
        |> assign(:api_key, "invalid")
        |> bypass_through(ApiWeb.Router, :api)

      {:ok, conn: conn}
    end

    test "forbids access", %{conn: conn} do
      conn = get(conn, @url)
      assert json_response(conn, :forbidden)["errors"]
    end
  end

  describe "requests" do
    setup %{conn: conn} do
      ApiWeb.RateLimiter.force_clear()
      {:ok, conn: conn}
    end

    test "have rate limiting headers in response", %{conn: conn} do
      conn = get(conn, @url)
      refute [] == get_resp_header(conn, "x-ratelimit-limit")
      refute [] == get_resp_header(conn, "x-ratelimit-remaining")
      refute [] == get_resp_header(conn, "x-ratelimit-reset")
    end
  end
end
