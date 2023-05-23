defmodule ApiWeb.Admin.SessionControllerTest do
  use ApiWeb.ConnCase, async: false

  @test_password "password"
  @authorized_user_attrs %{
    email: "authorized@mbta.com",
    role: "administrator",
    password: @test_password
  }
  @unauthorized_user_attrs %{
    email: "unauthorized@mbta.com",
    password: @test_password
  }

  def fixture(:totp_user) do
    time = DateTime.utc_now() |> DateTime.add(-35, :second)
    {:ok, user} = ApiAccounts.create_user(@authorized_user_attrs)
    {:ok, user} = ApiAccounts.register_totp(user)

    {:ok, user} =
      ApiAccounts.enable_totp(
        user,
        NimbleTOTP.verification_code(user.totp_secret_bin, time: time),
        time: time
      )

    user
  end

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
    assert get_flash(conn, :error) != nil
    assert html_response(conn, 200) =~ "Invalid credentials"
  end

  test "shows error for unauthorized users", %{conn: conn} do
    {:ok, _} = ApiAccounts.create_user(@unauthorized_user_attrs)

    conn =
      post(form_header(conn), admin_session_path(conn, :create), user: @unauthorized_user_attrs)

    assert html_response(conn, 200) =~ "Login"
    assert get_flash(conn, :error) != nil
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
    _user = fixture(:totp_user)

    conn =
      post(form_header(conn), admin_session_path(conn, :create), user: @authorized_user_attrs)

    assert redirected_to(conn) == admin_session_path(conn, :new_2fa)
  end

  test "2fa redirects user on success", %{conn: conn} do
    user = fixture(:totp_user)

    conn = conn |> conn_with_session() |> put_session(:inc_user_id, user.id)

    conn =
      post(
        form_header(conn),
        admin_session_path(conn, :create_2fa),
        user: %{totp_code: NimbleTOTP.verification_code(user.totp_secret_bin)}
      )

    assert redirected_to(conn) == admin_user_path(conn, :index)
  end

  test "2fa does not accept invalid codes", %{conn: conn} do
    user = fixture(:totp_user)

    conn = conn |> conn_with_session() |> put_session(:inc_user_id, user.id)

    conn =
      post(
        form_header(conn),
        admin_session_path(conn, :create_2fa),
        user: %{totp_code: "1234"}
      )

    assert html_response(conn, 200) =~ "TOTP"
    assert get_flash(conn, :error) != nil
  end
end
