defmodule ApiWeb.Portal.UserControllerTest do
  use ApiWeb.ConnCase, async: false

  setup %{conn: conn} do
    ApiAccounts.Dynamo.create_table(ApiAccounts.User)
    on_exit(fn -> ApiAccounts.Dynamo.delete_all_tables() end)
    {:ok, conn: conn}
  end

  describe "registration" do
    test "shows recaptcha widget", %{conn: conn} do
      conn = get(conn, user_path(conn, :new))

      assert html_response(conn, 200) =~
               "data-sitekey=\"6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI\""
    end

    test "renders register form", %{conn: conn} do
      conn = get(conn, user_path(conn, :new))
      assert html_response(conn, 200) =~ "Register</h2>"
    end

    test "creates a user and redirects on success", %{conn: conn} do
      valid_params = %{
        email: "test@test",
        password: "password",
        password_confirmation: "password"
      }

      conn =
        conn
        |> form_header()
        |> post(user_path(conn, :new), user: valid_params)

      assert redirected_to(conn) == portal_path(conn, :index)
      assert ApiAccounts.get_user_by_email!(valid_params.email)
    end

    test "shows errors for invalid form submission", %{conn: conn} do
      params = %{
        email: "test@test",
        password: "short",
        password_confirmation: ""
      }

      conn =
        conn
        |> form_header()
        |> post(user_path(conn, :new), user: params)

      page = html_response(conn, 200)
      assert page =~ "at least"
      assert page =~ "confirmation does not match"
    end

    test "shows error for duplicate email addresses", %{conn: conn} do
      params = %{
        email: "test@test",
        password: "password",
        password_confirmation: "password"
      }

      {:ok, _} = ApiAccounts.create_user(Map.take(params, [:email]))

      conn =
        conn
        |> form_header()
        |> post(user_path(conn, :new), user: params)

      page = html_response(conn, 200)
      assert page =~ "already been taken"
    end

    test "redirects already authenticated users", %{conn: conn} do
      {:ok, user} = ApiAccounts.create_user(%{email: "test@test"})

      conn =
        conn
        |> conn_with_session()
        |> conn_with_user(user)
        |> get(user_path(conn, :new))

      assert redirected_to(conn) == portal_path(conn, :index)
    end
  end

  describe "update password" do
    setup %{conn: conn} do
      params = %{email: "test@test", password: "password"}
      {:ok, user} = ApiAccounts.create_user(params)

      conn =
        conn
        |> conn_with_session()
        |> conn_with_user(user)

      {:ok, conn: conn}
    end

    test "shows password update form", %{conn: conn} do
      conn = get(conn, user_path(conn, :edit_password))
      page = html_response(conn, 200)
      assert page =~ user_path(conn, :update)
      assert page =~ ~r"update password"i
    end

    test "shows errors on invalid form submission", %{conn: conn} do
      params = %{
        action: "update-password",
        user: %{password: "new_password", password_confirmation: "password"}
      }

      conn =
        conn
        |> form_header()
        |> put(user_path(conn, :update), params)

      page = html_response(conn, 200)
      assert page =~ "match"
      refute get_flash(conn, :success)
    end

    test "updates a users password when valid", %{conn: conn} do
      params = %{
        action: "update-password",
        user: %{password: "new_password", password_confirmation: "new_password"}
      }

      conn =
        conn
        |> form_header()
        |> put(user_path(conn, :update), params)

      assert redirected_to(conn) == user_path(conn, :show)
      assert get_flash(conn, :success) =~ ~r"password updated"i
    end
  end

  describe "edit account" do
    setup %{conn: conn} do
      params = %{email: "test@test", password: "password"}
      {:ok, user} = ApiAccounts.create_user(params)

      conn =
        conn
        |> conn_with_session()
        |> conn_with_user(user)

      {:ok, conn: conn, user: user}
    end

    test "show account information update form", %{conn: conn} do
      conn = get(conn, user_path(conn, :edit))
      page = html_response(conn, 200)
      assert page =~ user_path(conn, :update)
      assert page =~ ~r"account information"i
    end

    test "shows error on invalid form submission", %{conn: conn} do
      {:ok, other_user} = ApiAccounts.create_user(%{email: "existing@test"})

      params = %{
        action: "edit-information",
        user: %{email: other_user.email}
      }

      conn =
        conn
        |> form_header()
        |> put(user_path(conn, :update), params)

      page = html_response(conn, 200)
      assert page =~ "already been taken"
      refute get_flash(conn, :success)
    end

    test "updates account information when valid", %{conn: conn} do
      params = %{
        action: "edit-information",
        user: %{email: "new@test.com", phone: "1234567"}
      }

      conn =
        conn
        |> form_header()
        |> put(user_path(conn, :update), params)

      assert redirected_to(conn) == user_path(conn, :show)
      assert get_flash(conn, :success) =~ ~r"account updated"i
    end
  end

  describe "forgot password" do
    test "shows the forgot password form", %{conn: conn} do
      conn = get(conn, user_path(conn, :forgot_password))
      page = html_response(conn, 200)
      assert page =~ "action=\"#{user_path(conn, :forgot_password_submit)}\""
    end

    test "shows errors when no email is submittted", %{conn: conn} do
      conn =
        conn
        |> form_header()
        |> post(user_path(conn, :forgot_password_submit), user: %{})

      page = html_response(conn, 200)
      assert page =~ "required"
      assert page =~ "format"
    end

    test "shows flash and redirects to home page when a known email is submited", %{conn: conn} do
      {:ok, user} = ApiAccounts.create_user(%{email: "test@test"})
      params = %{email: user.email}

      conn =
        conn
        |> form_header()
        |> post(user_path(conn, :forgot_password_submit), user: params)

      assert get_flash(conn, :info) =~ ~r"check your email"i
      assert redirected_to(conn) == portal_path(conn, :landing)
    end

    test "shows flash and redirects to home page when an unknown email is submited", %{conn: conn} do
      params = %{email: "test@test"}

      conn =
        conn
        |> form_header()
        |> post(user_path(conn, :forgot_password_submit), user: params)

      assert get_flash(conn, :info) =~ ~r"check your email"i
      assert redirected_to(conn) == portal_path(conn, :landing)
    end
  end

  describe "reset password" do
    def valid_token(user) do
      Phoenix.Token.sign(ApiWeb.Endpoint, "account recovery", user.id)
    end

    # `:signed_at` option not available until Phoenix 1.3 upgrade.
    def invalid_token(user) do
      two_days_in_seconds = 60 * 60 * 24 * 2
      signed_time = System.system_time(:seconds) - two_days_in_seconds
      opts = [signed_at: signed_time]
      Phoenix.Token.sign(ApiWeb.Endpoint, "account recovery", user.id, opts)
    end

    setup %{conn: conn} do
      {:ok, user} = ApiAccounts.create_user(%{email: "test@test"})
      {:ok, user: user, conn: conn}
    end

    test "shows reset form for valid tokens", %{conn: conn, user: user} do
      token = valid_token(user)
      conn = get(conn, user_path(conn, :reset_password, token: token))

      page = html_response(conn, 200)
      recovery_url = user_path(conn, :reset_password_submit, token: token)
      assert page =~ "action=\"#{recovery_url}\""
    end

    test "shows errors on form errors", %{conn: conn, user: user} do
      token = valid_token(user)

      params = %{
        password: "short",
        password_confirmation: "not_the_same"
      }

      conn =
        conn
        |> form_header()
        |> post(user_path(conn, :reset_password_submit, token: token), user: params)

      page = html_response(conn, 200)
      assert page =~ "at least"
      assert page =~ "match"
    end

    test "updates password and redirects to login", %{conn: conn, user: user} do
      token = valid_token(user)

      params = %{
        password: "new_password",
        password_confirmation: "new_password"
      }

      conn =
        conn
        |> form_header()
        |> post(user_path(conn, :reset_password_submit, token: token), user: params)

      assert redirected_to(conn) == session_path(conn, :new)
      assert get_flash(conn, :success) =~ "success"
      assert {:ok, _} = ApiAccounts.authenticate(%{email: user.email, password: params.password})
    end

    test "rejects invalid tokens", %{conn: base_conn, user: _user} do
      # expired_token = invalid_token(user)

      # conn = get(base_conn,
      #            user_path(base_conn, :reset_password, token: expired_token))
      # assert html_response(conn, 200) =~ ~r"invalid"

      conn = get(base_conn, user_path(base_conn, :reset_password))
      assert html_response(conn, 200) =~ ~r"invalid"
    end
  end
end
