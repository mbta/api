defmodule ApiWeb.Admin.Accounts.UserControllerTest do
  use ApiWeb.ConnCase

  @create_attrs %{
    active: true,
    blocked: true,
    join_date: ~N[2010-04-17 14:00:00.000000],
    phone: "some phone",
    role: "some role",
    username: "some username",
    email: "test@mbta.com"
  }
  @update_attrs %{
    active: false,
    blocked: false,
    join_date: ~N[2011-05-18 15:01:01.000000],
    phone: "",
    role: "some updated role",
    username: "some updated username",
    email: "new_test@mbta.com"
  }
  @invalid_attrs %{
    active: nil,
    blocked: nil,
    join_date: nil,
    phone: nil,
    role: nil,
    username: nil
  }

  def fixture(:user) do
    {:ok, user} = ApiAccounts.create_user(@create_attrs)
    user
  end

  def fixture(:mfa_user) do
    user = fixture(:user)
    {:ok, user} = ApiAccounts.generate_totp_secret(user)

    {:ok, user} =
      ApiAccounts.enable_totp(user, NimbleTOTP.verification_code(user.totp_secret_bin))

    user
  end

  setup %{conn: conn} do
    ApiAccounts.Dynamo.create_table(ApiAccounts.User)
    ApiAccounts.Dynamo.create_table(ApiAccounts.Key)

    on_exit(fn -> ApiAccounts.Dynamo.delete_all_tables() end)

    params = %{email: "admin@mbta.com", role: "administrator"}
    {:ok, user} = ApiAccounts.create_user(params)

    conn =
      conn
      |> conn_with_session()
      |> conn_with_user(user)

    {:ok, conn: conn}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get(conn, admin_user_path(conn, :index))
    assert html_response(conn, 200) =~ "Listing Users"
    user = fixture(:user)
    conn = get(conn, admin_user_path(conn, :index))
    assert html_response(conn, 200) =~ user.email
  end

  test "shows a user and their api keys", %{conn: conn} do
    user = fixture(:user)

    keys =
      for _ <- 1..5 do
        {:ok, key} = ApiAccounts.create_key(user)
        {:ok, key} = ApiAccounts.update_key(key, %{approved: true})
        key
      end

    conn = get(conn, admin_user_path(conn, :show, user))
    page = html_response(conn, 200)
    assert page =~ user.email

    for key <- keys do
      assert page =~ key.key
    end
  end

  test "renders form for new users", %{conn: conn} do
    conn = get(conn, admin_user_path(conn, :new))
    assert html_response(conn, 200) =~ "New User"
  end

  test "creates user and redirects to show when data is valid", %{conn: conn} do
    conn = post(form_header(conn), admin_user_path(conn, :create), user: @create_attrs)

    user =
      ApiAccounts.list_users()
      |> Enum.reject(fn user -> user.id == conn.assigns.user.id end)
      |> Enum.at(0)

    assert redirected_to(conn) == admin_user_path(conn, :show, user.id)

    conn = get(conn, admin_user_path(conn, :show, user.id))
    assert html_response(conn, 200) =~ "Show User"
  end

  test "does not create user and renders errors when data is invalid", %{conn: conn} do
    conn = post(form_header(conn), admin_user_path(conn, :create), user: @invalid_attrs)
    assert html_response(conn, 200) =~ "New User"
  end

  test "renders form for editing chosen user", %{conn: conn} do
    user = fixture(:user)
    conn = get(conn, admin_user_path(conn, :edit, user))
    assert html_response(conn, 200) =~ "Edit User"
  end

  test "updates chosen user and redirects when data is valid", %{conn: conn} do
    user = fixture(:user)
    conn = put(form_header(conn), admin_user_path(conn, :update, user), user: @update_attrs)
    assert redirected_to(conn) == admin_user_path(conn, :show, user)

    conn = get(conn, admin_user_path(conn, :show, user))
    assert html_response(conn, 200) =~ "some updated username"
  end

  test "does not update chosen user and renders errors when data is invalid", %{conn: conn} do
    user = fixture(:user)
    conn = put(form_header(conn), admin_user_path(conn, :update, user), user: @invalid_attrs)
    assert html_response(conn, 200) =~ "Edit User"
  end

  test "deletes chosen user", %{conn: base_conn} do
    user = fixture(:user)
    conn = delete(form_header(base_conn), admin_user_path(base_conn, :delete, user))
    assert redirected_to(conn) == admin_user_path(conn, :index)

    assert_error_sent(:not_found, fn ->
      get(base_conn, admin_user_path(base_conn, :show, user))
    end)
  end

  test "displays button to disable mfa", %{conn: conn} do
    user = fixture(:mfa_user)
    conn = get(conn, admin_user_path(conn, :show, user))

    assert page = html_response(conn, 200)
    assert page =~ "Disable MFA"
  end

  test "disables MFA for user", %{conn: conn} do
    user = fixture(:mfa_user)
    conn = post(conn, admin_user_path(conn, :disable_2fa, user), %{})

    assert redirected_to(conn) == admin_user_path(conn, :show, user)

    conn = get(conn, admin_user_path(conn, :show, user))

    assert page = html_response(conn, 200)
    refute page =~ "Disable MFA"
  end
end
