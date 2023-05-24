defmodule ApiWeb.MFAController do
  @moduledoc false
  use ApiWeb.Web, :controller

  def new(conn, _params) do
    user = conn |> get_session(:inc_user_id) |> ApiAccounts.get_user!()
    change = ApiAccounts.change_user(user)

    conn
    |> render("new.html", changeset: change)
  end

  def create(conn, params) do
    user = conn |> get_session(:inc_user_id) |> ApiAccounts.get_user!()

    case ApiAccounts.validate_totp(user, params["user"]["totp_code"]) do
      {:ok, user} ->
        destination = get_session(conn, :destination)

        conn
        |> delete_session(:inc_user_id)
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> delete_session(:destination)
        |> redirect(to: destination)

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Invalid code. Please try again.")
        |> render("new.html", changeset: changeset)
    end
  end
end
