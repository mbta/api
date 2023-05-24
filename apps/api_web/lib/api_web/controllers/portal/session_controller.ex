defmodule ApiWeb.ClientPortal.SessionController do
  @moduledoc false
  use ApiWeb.Web, :controller

  plug(ApiWeb.Plugs.RedirectAlreadyAuthenticated when action in [:new, :create])

  def new(conn, _) do
    changeset = ApiAccounts.change_user(%ApiAccounts.User{})

    conn
    |> assign(:pre_container_template, "_new.html")
    |> render("new.html", changeset: changeset)
  end

  def create(conn, %{"user" => credentials}) do
    case ApiAccounts.authenticate(credentials) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: portal_path(conn, :index))

      {:continue, :totp, user} ->
        conn
        |> put_session(:inc_user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: session_path(conn, :new_2fa))

      {:error, %ApiAccounts.Changeset{} = changeset} ->
        conn
        |> assign(:pre_container_template, "_new.html")
        |> render("new.html", changeset: changeset)

      {:error, :invalid_credentials} ->
        changeset = ApiAccounts.change_user(%ApiAccounts.User{})

        conn
        |> put_flash(:error, "Invalid credentials. Please try again.")
        |> assign(:pre_container_template, "_new.html")
        |> render("new.html", changeset: changeset)
    end
  end

  def new_2fa(conn, _params) do
    user = conn |> get_session(:inc_user_id) |> ApiAccounts.get_user!()
    change = ApiAccounts.change_user(user)

    conn
    |> render("new_2fa.html", changeset: change)
  end

  def create_2fa(conn, params) do
    user = conn |> get_session(:inc_user_id) |> ApiAccounts.get_user!()

    case ApiAccounts.validate_totp(user, params["user"]["totp_code"]) do
      {:ok, user} ->
        conn
        |> delete_session(:inc_user_id)
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: portal_path(conn, :index))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Invalid code. Please try again.")
        |> render("new_2fa.html", changeset: changeset)
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_session(:user_id)
    |> put_flash(:info, "You have successfully logged out.")
    |> redirect(to: session_path(conn, :new))
  end
end
