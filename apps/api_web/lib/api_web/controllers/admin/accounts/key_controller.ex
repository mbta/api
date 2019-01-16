defmodule ApiWeb.Admin.Accounts.KeyController do
  @moduledoc false
  use ApiWeb.Web, :controller

  plug(:api_versions)
  plug(:fetch_user when action not in [:index, :redirect_to_user_by_id, :find_user_by_key])

  def index(conn, _params) do
    key_requests = ApiAccounts.list_key_requests()

    render(conn, "index.html", key_requests: key_requests)
  end

  def create(conn, _params) do
    user = conn.assigns.user
    {:ok, key} = ApiAccounts.create_key(user)
    {:ok, _} = ApiAccounts.update_key(key, %{requested_date: key.created, approved: true})

    conn
    |> put_flash(:info, "Key created successfully.")
    |> redirect(to: admin_user_path(conn, :show, user))
  end

  def edit(conn, %{"id" => key_id}) do
    key = ApiAccounts.get_key!(key_id)
    user = conn.assigns.user
    changeset = ApiAccounts.change_key(key)
    render(conn, "edit.html", user: user, key: key, changeset: changeset)
  end

  def update(conn, %{"id" => key_id, "key" => key_params}) do
    key_params = Map.put(key_params, :rate_request_pending, false)
    key = ApiAccounts.get_key!(key_id)
    user = conn.assigns.user
    # normally we would do this validation in ApiAccounts, but that
    # application doesn't know which API versions are valid.
    key_params =
      case key_params do
        %{"api_version" => version} ->
          if version in conn.assigns.api_versions do
            key_params
          else
            Map.delete(key_params, "api_version")
          end

        _ ->
          key_params
      end

    case ApiAccounts.update_key(key, key_params) do
      {:ok, key} ->
        ApiAccounts.Keys.cache_key(key)

        conn
        |> put_flash(:info, "Key updated successfully.")
        |> redirect(to: admin_user_path(conn, :show, user))

      {:error, %ApiAccounts.Changeset{} = changeset} ->
        render(conn, "edit.html", user: user, key: key, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => key_id} = params) do
    user = conn.assigns.user
    key = ApiAccounts.get_key!(key_id)
    :ok = ApiAccounts.delete_key(key)
    _ = ApiAccounts.Keys.revoke_key(key)

    _ =
      if params["action"] == "reject" do
        ApiAccounts.Notifications.send_key_request_rejected(user)
      end

    conn
    |> put_flash(:info, "Key deleted successfully.")
    |> redirect(to: admin_user_path(conn, :show, user))
  end

  def approve(conn, %{"id" => key_id}) do
    params = %{approved: true, created: DateTime.utc_now()}
    user = conn.assigns.user
    key = ApiAccounts.get_key!(key_id)
    {:ok, key} = ApiAccounts.update_key(key, params)
    url = portal_url(conn, :landing)
    _ = ApiAccounts.Notifications.send_key_request_approved(user, key, url)

    conn
    |> put_flash(:info, "Key approved successfully.")
    |> redirect(to: admin_user_path(conn, :show, user))
  end

  def redirect_to_user_by_id(conn, %{"key" => key_id}) do
    key = ApiAccounts.get_key!(key_id)
    user = ApiAccounts.get_user!(key.user_id)
    redirect(conn, to: admin_user_path(conn, :show, user))
  end

  def find_user_by_key(conn, %{"search" => %{"key" => key_id}}) do
    case ApiAccounts.get_key(key_id) do
      {:ok, key} ->
        user = ApiAccounts.get_user!(key.user_id)
        redirect(conn, to: admin_user_path(conn, :show, user))

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "A Key with the id #{key_id} was not found.")
        |> redirect(to: admin_key_path(conn, :index))
    end
  end

  defp fetch_user(conn, _) do
    %{"user_id" => user_id} = conn.params
    user = ApiAccounts.get_user!(user_id)
    assign(conn, :user, user)
  end

  defp api_versions(conn, _) do
    assign(conn, :api_versions, Application.get_env(:api_web, :versions)[:versions])
  end
end
