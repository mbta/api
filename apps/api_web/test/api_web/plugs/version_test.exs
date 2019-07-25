defmodule ApiWeb.Plugs.VersionTest do
  @moduledoc false
  use ApiWeb.ConnCase
  import ApiWeb.Plugs.Version

  @api_key String.duplicate("v", 32)
  @default_version Application.get_env(:api_web, :versions)[:default]
  @opts init([])

  setup %{conn: conn} do
    conn =
      conn
      |> bypass_through(ApiWeb.Router, :api)
      |> Map.put(:assigns, %{})

    Logger.metadata(api_version: :unset)

    {:ok, %{conn: conn}}
  end

  describe "init/1" do
    test "returns opts" do
      assert init([]) == []
    end
  end

  describe "call/2" do
    test "anonymous user gets the default version", %{conn: conn} do
      conn =
        conn
        |> assign_api_user(anonymous_user())
        |> call(@opts)

      assert conn.assigns.api_version == @default_version
    end

    test "authenticated user gets their specified version", %{conn: conn} do
      conn =
        conn
        |> assign_api_user(user_with_version("2018-05-07"))
        |> call(@opts)

      assert conn.assigns.api_version == "2018-05-07"
    end

    test "MBTA-Version header overrides a user's default", %{conn: conn} do
      conn =
        conn
        |> put_req_header("mbta-version", "2017-11-28")
        |> assign_api_user(user_with_version("2018-05-07"))
        |> call(@opts)

      assert conn.assigns.api_version == "2017-11-28"
    end

    test "header ignores invalid values", %{conn: conn} do
      conn =
        conn
        |> put_req_header("mbta-version", "1970-01-01")
        |> assign_api_user(user_with_version("2018-05-07"))
        |> call(@opts)

      assert conn.assigns.api_version == "2018-05-07"
    end

    test "assigns version to the Logger metadata", %{conn: conn} do
      _conn =
        conn
        |> assign_api_user(anonymous_user())
        |> call(@opts)

      assert Logger.metadata()[:api_version] == @default_version
    end
  end

  defp assign_api_user(conn, api_user) do
    Plug.Conn.assign(conn, :api_user, api_user)
  end

  defp anonymous_user do
    ApiWeb.User.anon({127, 0, 0, 1})
  end

  defp user_with_version(version) do
    key = %ApiAccounts.Key{key: @api_key, api_version: version}
    ApiWeb.User.from_key(key)
  end
end
