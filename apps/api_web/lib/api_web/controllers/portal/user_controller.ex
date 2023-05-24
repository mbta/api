defmodule ApiWeb.ClientPortal.UserController do
  @moduledoc false
  use ApiWeb.Web, :controller

  @redirect_routes [
    :new,
    :create,
    :forgot_password,
    :forgot_password_submit,
    :reset_password,
    :reset_password_submit
  ]
  plug(ApiWeb.Plugs.RedirectAlreadyAuthenticated when action in @redirect_routes)

  def new(conn, _) do
    changeset = ApiAccounts.change_user(%ApiAccounts.User{})

    conn
    |> assign(:pre_container_template, "_new.html")
    |> render("new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params, "g-recaptcha-response" => recaptcha}) do
    _create(conn, user_params, recaptcha)
  end

  # Allow missing recaptcha response
  def create(conn, %{"user" => user_params}) do
    _create(conn, user_params, nil)
  end

  defp _create(conn, user_params, recaptcha) do
    # Only test recaptcha if the feature is enabled (prod):
    recaptcha_verified =
      if Application.get_env(:recaptcha, :enabled) do
        Recaptcha.verify(recaptcha)
      else
        {:ok, false}
      end

    with {:ok, _recaptcha} <-
           recaptcha_verified,
         {:ok, user} <-
           ApiAccounts.register_user(user_params) do
      conn
      |> put_session(:user_id, user.id)
      |> configure_session(renew: true)
      |> redirect(to: portal_path(conn, :index))
    else
      {:error, %ApiAccounts.Changeset{} = changeset} ->
        conn
        |> assign(:pre_container_template, "_new.html")
        |> render("new.html", changeset: changeset)

      {:error, _errors} ->
        # Retain form values:
        changeset =
          ApiAccounts.User.changeset(struct(%ApiAccounts.User{}, user_params), user_params)

        conn
        |> put_flash(:error, "Registration failed due to incorrect or missing captcha.")
        |> assign(:pre_container_template, "_new.html")
        |> render("new.html", changeset: changeset)
    end
  end

  def show(conn, _) do
    render(conn, "show.html")
  end

  def edit(conn, _) do
    changeset = ApiAccounts.change_user(conn.assigns.user)
    render(conn, "edit.html", changeset: changeset)
  end

  def edit_password(conn, _) do
    changeset = ApiAccounts.change_user(%ApiAccounts.User{})
    render(conn, "edit_password.html", changeset: changeset)
  end

  def update(conn, %{"action" => "edit-information", "user" => user}) do
    case ApiAccounts.update_information(conn.assigns.user, user) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Account updated successfully.")
        |> redirect(to: user_path(conn, :show))

      {:error, %ApiAccounts.Changeset{} = changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  def update(conn, %{"action" => "update-password", "user" => user}) do
    case ApiAccounts.update_password(conn.assigns.user, user) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Password updated successfully.")
        |> redirect(to: user_path(conn, :show))

      {:error, %ApiAccounts.Changeset{} = changeset} ->
        render(conn, "edit_password.html", changeset: changeset)
    end
  end

  def forgot_password(conn, _) do
    changeset = ApiAccounts.change_user(%ApiAccounts.User{})

    conn
    |> assign(:pre_container_template, "_forgot_password.html")
    |> render("forgot_password.html", changeset: changeset)
  end

  def forgot_password_submit(conn, %{"user" => user}) do
    case ApiAccounts.get_user_by_email(user) do
      {:ok, user} ->
        token = Phoenix.Token.sign(ApiWeb.Endpoint, "account recovery", user.id)
        password_reset_url = user_url(conn, :reset_password, token: token)
        _ = ApiAccounts.Notifications.send_password_reset(user, password_reset_url)

        conn
        |> put_flash(:info, "Check your email for further instructions.")
        |> redirect(to: portal_path(conn, :landing))

      {:error, %ApiAccounts.Changeset{} = changeset} ->
        conn
        |> assign(:pre_container_template, "_forgot_password.html")
        |> render("forgot_password.html", changeset: changeset)

      {:error, :not_found} ->
        conn
        |> put_flash(:info, "Check your email for further instructions.")
        |> redirect(to: portal_path(conn, :landing))
    end
  end

  def reset_password(conn, params) do
    case user_for_token(params) do
      {:ok, _user} ->
        changeset = ApiAccounts.change_user(%ApiAccounts.User{})
        token = params["token"]
        render(conn, "reset_password.html", changeset: changeset, token: token)

      _ ->
        render(conn, "invalid_reset_password.html")
    end
  end

  def configure_2fa(conn, _) do
    user = conn.assigns[:user]
    render(conn, "configure_2fa.html", enabled: user.totp_enabled)
  end

  def register_2fa(conn, params) do
    code = get_in(params, ["user", "totp_code"])

    if code do
      user = conn.assigns[:user]

      case ApiAccounts.enable_totp(user, code) do
        {:ok, _user} ->
          conn
          |> put_flash(:success, "2FA enabled successfully.")
          |> redirect(to: user_path(conn, :show))

        {:error, changeset} ->
          uri = ApiAccounts.totp_uri(user)
          {:ok, qr_code} = uri |> QRCode.create() |> QRCode.render(:svg) |> QRCode.to_base64()

          render(conn, "register_2fa.html",
            secret: user.totp_secret,
            qr_code: "data:image/svg+xml;base64, #{qr_code}",
            changeset: changeset
          )
      end
    else
      {:ok, user} = ApiAccounts.register_totp(conn.assigns[:user])
      uri = ApiAccounts.totp_uri(user)
      {:ok, qr_code} = uri |> QRCode.create() |> QRCode.render(:svg) |> QRCode.to_base64()

      render(conn, "register_2fa.html",
        secret: user.totp_secret,
        qr_code: "data:image/svg+xml;base64, #{qr_code}",
        changeset: ApiAccounts.change_user(user)
      )
    end
  end

  def unenroll_2fa(conn, _params) do
    render(conn, "unenroll_2fa.html", changeset: ApiAccounts.change_user(conn.assigns[:user]))
  end

  def disable_2fa(conn, params) do
    code = get_in(params, ["user", "totp_code"])

    case ApiAccounts.disable_totp(conn.assigns[:user], code) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "2FA disabled successfully.")
        |> redirect(to: user_path(conn, :show))

      {:error, changeset} ->
        render(conn, "unenroll_2fa.html", changeset: changeset)
    end
  end

  def reset_password_submit(conn, params) do
    with {:ok, user_id} <- user_for_token(params),
         {:ok, user} <- ApiAccounts.get_user(user_id),
         {:ok, _user} <- ApiAccounts.update_password(user, params["user"]) do
      conn
      |> put_flash(:success, "Password updated successfully.")
      |> redirect(to: session_path(conn, :new))
    else
      {:error, %ApiAccounts.Changeset{} = changeset} ->
        token = params["token"]
        render(conn, "reset_password.html", changeset: changeset, token: token)

      _ ->
        render(conn, "invalid_reset_password.html")
    end
  end

  defp user_for_token(%{"token" => token}) do
    case Phoenix.Token.verify(ApiWeb.Endpoint, "account recovery", token, max_age: 86_400) do
      {:ok, _user_id} = good ->
        good

      _ ->
        :error
    end
  end

  defp user_for_token(_), do: :error
end
