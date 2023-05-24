defmodule ApiWeb.Admin.SessionController do
  @moduledoc false
  use ApiWeb.Web, :controller

  plug(:redirect_already_authorized when action in [:new, :create])
  plug(ApiWeb.Plugs.RequireAdmin when action in [:delete])

  def new(conn, _) do
    changeset = ApiAccounts.change_user(%ApiAccounts.User{})
    render(conn, "login.html", changeset: changeset)
  end

  def create(conn, %{"user" => credentials}) do
    with {:ok, user} <- ApiAccounts.authenticate(credentials),
         %{role: "administrator"} <- user do
      conn
      |> put_session(:user_id, user.id)
      |> configure_session(renew: true)
      |> redirect(to: admin_user_path(conn, :index))
    else
      {:continue, :totp, user = %ApiAccounts.User{role: "administrator"}} ->
        conn
        |> put_session(:inc_user_id, user.id)
        |> configure_session(renew: true)
        |> redirect(to: admin_session_path(conn, :new_2fa))

      {:error, %ApiAccounts.Changeset{} = changeset} ->
        render(conn, "login.html", changeset: changeset)

      {:error, :invalid_credentials} ->
        changeset = ApiAccounts.change_user(%ApiAccounts.User{})

        conn
        |> put_flash(:error, "Invalid credentials. Please try again.")
        |> render("login.html", changeset: changeset)

      %ApiAccounts.User{} ->
        changeset = ApiAccounts.change_user(%ApiAccounts.User{})

        conn
        |> put_flash(:error, "You are not authorized to continue.")
        |> render("login.html", changeset: changeset)
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
        |> redirect(to: admin_user_path(conn, :index))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Invalid code. Please try again.")
        |> render("new_2fa.html", changeset: changeset)
    end
  end

  def delete(conn, _) do
    conn
    |> delete_session(:user_id)
    |> put_flash(:info, "You have successfully logged out.")
    |> redirect(to: admin_session_path(conn, :new))
  end

  defp redirect_already_authorized(conn, _) do
    case conn.assigns[:user] do
      %{role: "administrator"} ->
        conn
        |> redirect(to: admin_user_path(conn, :index))
        |> halt()

      _ ->
        conn
    end
  end
end
