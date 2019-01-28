defmodule ApiWeb.Plugs.CorsTest do
  import Phoenix.ConnTest
  use ApiAccounts.Test.DatabaseCase, async: false
  use ApiWeb.ConnCase, async: false

  @url "/stops/"

  test "init" do
    assert ApiWeb.Plugs.CORS.init([]) == []
  end

  describe "requests with no api key" do
    setup %{conn: conn} do
      conn =
        conn
        |> assign(:api_key, nil)
        |> put_req_header("origin", "http://foo.com")

      {:ok, conn: conn}
    end

    test "assigns anonymous user and receives access-control-allow-origin *", %{conn: conn} do
      conn = get(conn, @url)
      assert %ApiWeb.User{type: :anon} = conn.assigns.api_user
      assert {"access-control-allow-origin", "*"} in conn.resp_headers
    end
  end

  describe "requests with a valid key" do
    test "returns * as default access-control-allow-origin", %{conn: conn} do
      conn =
        conn
        |> put_req_header("origin", "http://foo.com")
        |> get(@url)

      assert {"access-control-allow-origin", "*"} in conn.resp_headers
    end

    test "returns matching access-control-allow-origin", %{conn: conn} do
      {:ok, user} = ApiAccounts.create_user(%{email: "test@test.com"})
      {:ok, new_key} = ApiAccounts.create_key(user)

      conn = assign(conn, :api_key, new_key.key)

      {:ok, _} =
        ApiAccounts.update_key(new_key, %{
          allowed_domains: "http://foo.com, http://bar.com",
          approved: true
        })

      foo_conn =
        conn
        |> put_req_header("origin", "http://foo.com")
        |> put_req_header("api-key", new_key.key)
        |> get(@url)

      assert get_resp_header(foo_conn, "access-control-allow-origin") == ["http://foo.com"]

      bar_conn =
        conn
        |> put_req_header("origin", "http://bar.com")
        |> put_req_header("api-key", new_key.key)
        |> get(@url)

      assert get_resp_header(bar_conn, "access-control-allow-origin") == ["http://bar.com"]

      invalid_origin_conn =
        conn
        |> put_req_header("origin", "http://baz.com")
        |> put_req_header("api-key", new_key.key)
        |> get(@url)

      assert %{halted: true, status: 400} = invalid_origin_conn
    end
  end
end
