defmodule ApiWeb.Portal.SessionControllerTest do
  use ApiWeb.ConnCase, async: false

  alias ApiWeb.Fixtures

  @test_password "password"
  @valid_user_attrs %{
    email: "authorized@example.com",
    password: @test_password
  }
  @invalid_user_attrs %{
    email: "unauthorized@example.com",
    password: @test_password
  }

  setup %{conn: conn} do
    ApiAccounts.Dynamo.create_table(ApiAccounts.User)
    on_exit(fn -> ApiAccounts.Dynamo.delete_all_tables() end)
    {:ok, conn: conn}
  end

  test "renders login form", %{conn: conn} do
    conn = get(conn, session_path(conn, :new))
    assert html_response(conn, 200) =~ "Login"
  end

  test "doesn't login when credentials aren't provided", %{conn: conn} do
    conn = post(form_header(conn), session_path(conn, :create), user: %{})
    assert html_response(conn, 200) =~ "Login"
  end

  test "shows error for invalid credentials", %{conn: conn} do
    conn = post(form_header(conn), session_path(conn, :create), user: @invalid_user_attrs)
    assert html_response(conn, 200) =~ "Login"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) != nil
    assert html_response(conn, 200) =~ "Invalid credentials"
  end

  test "redirects user on success", %{conn: conn} do
    {:ok, _} = ApiAccounts.create_user(@valid_user_attrs)
    conn = post(form_header(conn), session_path(conn, :create), user: @valid_user_attrs)
    assert redirected_to(conn) == portal_path(conn, :index)
  end

  test "redirects already authenticated users", %{conn: conn} do
    {:ok, user} = ApiAccounts.create_user(@valid_user_attrs)

    conn =
      conn
      |> conn_with_session()
      |> conn_with_user(user)

    conn = get(conn, session_path(conn, :new))
    assert redirected_to(conn) == portal_path(conn, :index)
  end

  test "logs out an authenticated user", %{conn: conn} do
    {:ok, user} = ApiAccounts.create_user(@valid_user_attrs)

    conn =
      conn
      |> conn_with_session()
      |> conn_with_user(user)

    conn = delete(conn, session_path(conn, :delete))
    refute get_session(conn, :user)
    assert redirected_to(conn) == session_path(conn, :new)
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ ~r"logged out"i
  end

  test "redirects to 2fa page when user has 2fa enabled", %{conn: conn} do
    _user = Fixtures.fixture(:totp_user)

    conn = post(form_header(conn), session_path(conn, :create), user: @valid_user_attrs)

    assert redirected_to(conn) == mfa_path(conn, :new)
  end
end
