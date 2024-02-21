defmodule ApiWeb.Admin.SessionControllerTest do
  use ApiWeb.ConnCase, async: false

  alias ApiWeb.Fixtures

  @test_password "password"
  @authorized_user_attrs %{
    email: "authorized@example.com",
    role: "administrator",
    totp_enabled: true,
    password: @test_password
  }
  @unauthorized_user_attrs %{
    email: "unauthorized@example.com",
    password: @test_password
  }

  setup %{conn: conn} do
    ApiAccounts.Dynamo.create_table(ApiAccounts.User)
    on_exit(fn -> ApiAccounts.Dynamo.delete_all_tables() end)
    {:ok, conn: conn}
  end

  test "renders login form", %{conn: conn} do
    conn = get(conn, admin_session_path(conn, :new))
    assert html_response(conn, 200) =~ "Login"
  end

  test "doesn't login when credentials aren't provided", %{conn: conn} do
    conn = post(form_header(conn), admin_session_path(conn, :create), user: %{})
    assert html_response(conn, 200) =~ "Login"
  end

  test "shows error for invalid credentials", %{conn: conn} do
    conn =
      post(
        form_header(conn),
        admin_session_path(conn, :create),
        user: %{email: "not@found", password: "password"}
      )

    assert html_response(conn, 200) =~ "Login"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) != nil
    assert html_response(conn, 200) =~ "Invalid credentials"
  end

  test "shows error for unauthorized users", %{conn: conn} do
    {:ok, _} = ApiAccounts.create_user(@unauthorized_user_attrs)

    conn =
      post(form_header(conn), admin_session_path(conn, :create), user: @unauthorized_user_attrs)

    assert html_response(conn, 200) =~ "Login"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) != nil
    assert html_response(conn, 200) =~ "not authorized"
  end

  test "redirects authorized used on success", %{conn: conn} do
    {:ok, _} = ApiAccounts.create_user(@authorized_user_attrs)

    conn =
      post(form_header(conn), admin_session_path(conn, :create), user: @authorized_user_attrs)

    assert redirected_to(conn) == admin_user_path(conn, :index)
  end

  test "redirects already authenticated/authorized users", %{conn: conn} do
    {:ok, user} = ApiAccounts.create_user(@authorized_user_attrs)

    conn =
      conn
      |> conn_with_session()
      |> conn_with_user(user)

    conn = get(conn, admin_session_path(conn, :new))
    assert redirected_to(conn) == admin_user_path(conn, :index)
  end

  test "logout redirects to login", %{conn: conn} do
    {:ok, user} = ApiAccounts.create_user(@authorized_user_attrs)

    conn =
      conn
      |> conn_with_session()
      |> conn_with_user(user)

    conn = delete(conn, admin_session_path(conn, :delete))
    refute Plug.Conn.get_session(conn, :user_id)
    assert redirected_to(conn) == admin_session_path(conn, :new)
  end

  test "redirects to 2fa page when user has 2fa enabled", %{conn: conn} do
    user = Fixtures.fixture(:totp_user)
    {:ok, _user} = ApiAccounts.update_user(user, %{role: "administrator"})

    conn =
      post(form_header(conn), admin_session_path(conn, :create), user: @authorized_user_attrs)

    assert redirected_to(conn) == mfa_path(conn, :new)
  end
end
