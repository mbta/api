defmodule ApiWeb.Admin.Accounts.UserController do
  @moduledoc false
  use ApiWeb.Web, :controller

  def index(conn, _params) do
    users = ApiAccounts.list_users()
    render(conn, "index.html", users: users)
  end

  def new(conn, _params) do
    changeset = ApiAccounts.change_user(%ApiAccounts.User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case ApiAccounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: admin_user_path(conn, :show, user))

      {:error, %ApiAccounts.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    user = ApiAccounts.get_user!(id)
    keys = ApiAccounts.list_keys_for_user(user)
    render(conn, "show.html", user: user, keys: keys)
  end

  def edit(conn, %{"id" => id}) do
    user = ApiAccounts.get_user!(id)
    changeset = ApiAccounts.change_user(user)
    render(conn, "edit.html", user: user, changeset: changeset)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = ApiAccounts.get_user!(id)

    case ApiAccounts.update_user(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User updated successfully.")
        |> redirect(to: admin_user_path(conn, :show, user))

      {:error, %ApiAccounts.Changeset{} = changeset} ->
        render(conn, "edit.html", user: user, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = ApiAccounts.get_user!(id)
    :ok = ApiAccounts.delete_user(user)

    conn
    |> put_flash(:info, "User deleted successfully.")
    |> redirect(to: admin_user_path(conn, :index))
  end
end
