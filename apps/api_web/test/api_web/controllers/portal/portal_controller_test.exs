defmodule ApiWeb.Controllers.Portal.PortalControllerTest do
  use ApiWeb.ConnCase

  describe "Test portal with keys" do
    setup :setup_key_requesting_user

    test "index loads", %{conn: conn} do
      conn = get(conn, portal_path(conn, :index))
      assert html_response(conn, 200) =~ "Api Keys"
    end

    test "index displays default key limit per minute", %{
      user: user,
      conn: conn
    } do
      {:ok, key} = ApiAccounts.create_key(user)
      {:ok, _} = ApiAccounts.update_key(key, %{approved: true})
      conn = get(conn, portal_path(conn, :index))
      max = ApiWeb.config(:rate_limiter, :max_registered_per_interval)
      interval = ApiWeb.config(:rate_limiter, :clear_interval)
      per_interval_minute = div(max, interval) * 60_000
      assert html_response(conn, 200) =~ "#{per_interval_minute}"
    end

    test "index displays dynamic key limit", %{user: user, conn: conn} do
      {:ok, key} = ApiAccounts.create_key(user)
      {:ok, _} = ApiAccounts.update_key(key, %{approved: true, daily_limit: 999_999_999_999})
      conn = get(conn, portal_path(conn, :index))
      assert html_response(conn, 200) =~ "694444200"
    end
  end

  test "landing", %{conn: conn} do
    conn = get(conn, portal_path(conn, :landing))
    assert html_response(conn, 200) =~ "<h1>MBTA V3 API Portal</h1>"
  end
end
