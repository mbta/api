defmodule ApiWeb.Portal.SessionControllerTest do
  use ApiWeb.ConnCase, async: false

  @test_password "password"
  @valid_user_attrs %{
    email: "authorized@mbta.com",
    password: @test_password
  }
  @invalid_user_attrs %{
    email: "unauthorized@mbta.com",
    password: @test_password
  }

  def fixture(:totp_user) do
    time = DateTime.utc_now() |> DateTime.add(-35, :second)
    {:ok, user} = ApiAccounts.create_user(@valid_user_attrs)
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
    assert get_flash(conn, :error) != nil
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
    assert get_flash(conn, :info) =~ ~r"logged out"i
  end

  test "redirects to 2fa page when user has 2fa enabled", %{conn: conn} do
    _user = fixture(:totp_user)

    conn = post(form_header(conn), session_path(conn, :create), user: @valid_user_attrs)

    assert redirected_to(conn) == session_path(conn, :new_2fa)
  end

  test "2fa redirects user on success", %{conn: conn} do
    user = fixture(:totp_user)

    conn = conn |> conn_with_session() |> put_session(:inc_user_id, user.id)

    conn =
      post(
        form_header(conn),
        session_path(conn, :create_2fa),
        user: %{totp_code: NimbleTOTP.verification_code(user.totp_secret_bin)}
      )

    assert redirected_to(conn) == portal_path(conn, :index)
  end

  test "2fa does not accept invalid codes", %{conn: conn} do
    user = fixture(:totp_user)

    conn = conn |> conn_with_session() |> put_session(:inc_user_id, user.id)

    conn =
      post(
        form_header(conn),
        session_path(conn, :create_2fa),
        user: %{totp_code: "1234"}
      )

    assert html_response(conn, 200) =~ "TOTP"
    assert get_flash(conn, :error) != nil
  end
end
