defmodule ApiWeb.Plugs.AuthenticateTest do
  @moduledoc false
  use ApiWeb.ConnCase, async: false
  import ApiWeb.Plugs.Authenticate

  @api_key String.duplicate("v", 32)
  @opts init([])

  setup %{conn: conn} do
    ApiWeb.RateLimiter.force_clear()

    conn =
      conn
      |> bypass_through(ApiWeb.Router, :api)
      |> Map.put(:assigns, %{})

    Logger.metadata(api_key: :unset, ip: :unset)

    {:ok, %{conn: conn}}
  end

  test "opts" do
    assert init([]) == []
  end

  test "assigned anonymous user with no API key", %{conn: base_conn} do
    conn = call(base_conn, [])
    assert %ApiWeb.User{type: :anon} = conn.assigns.api_user
  end

  test "assigned registered user with valid API key", %{conn: base_conn} do
    conn = conn_with_key(base_conn, @api_key)
    conn = call(conn, @opts)
    assert %ApiWeb.User{type: :registered} = conn.assigns.api_user
    refute "api_key" in Map.keys(conn.query_params)
    refute "api_key" in Map.keys(conn.params)
  end

  test "assigned registered user with valid API key from header", %{conn: base_conn} do
    conn =
      base_conn
      |> Plug.Conn.put_req_header("x-api-key", @api_key)
      |> call(@opts)

    assert %ApiWeb.User{type: :registered} = conn.assigns.api_user
  end

  test "gives a 403 status with invalid API key", %{conn: base_conn} do
    conn = conn_with_key(base_conn, "invalid")
    conn = call(conn, @opts)
    assert %{"errors" => [error]} = json_response(conn, 403)
    assert %{"status" => "403", "code" => "forbidden"} = error
  end

  test "uses `X-Forwarded-For` for anon user if present", %{conn: base_conn} do
    conn = call(base_conn, @opts)
    assert %ApiWeb.User{id: "127.0.0.1", type: :anon} = conn.assigns.api_user

    conn =
      base_conn
      |> Plug.Conn.put_req_header("x-forwarded-for", "test")
      |> call(@opts)

    assert %ApiWeb.User{id: "test", type: :anon} = conn.assigns.api_user
  end

  test "registered user puts api_key in Logger.metadata", %{conn: conn} do
    _ =
      conn
      |> conn_with_key(@api_key)
      |> call(@opts)

    assert Logger.metadata()[:api_key] == @api_key
    refute Logger.metadata()[:ip]
  end

  test "invalid API key puts api_key and IP in Logger.metadata", %{conn: conn} do
    _ =
      conn
      |> conn_with_key("invalid")
      |> call(@opts)

    assert Logger.metadata()[:api_key] == "invalid"
    assert Logger.metadata()[:ip] == "127.0.0.1"
  end

  test "anonymous user puts IP in Logger.metadata", %{conn: conn} do
    _ = call(conn, @opts)

    assert Logger.metadata()[:api_key] == "anonymous"
    assert Logger.metadata()[:ip] == "127.0.0.1"
  end

  defp conn_with_key(conn, key) do
    params = %{"api_key" => key}
    %{conn | query_params: params, params: params}
  end
end
