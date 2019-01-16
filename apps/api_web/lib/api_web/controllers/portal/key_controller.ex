defmodule ApiWeb.ClientPortal.KeyController do
  @moduledoc false
  use ApiWeb.Web, :controller

  plug(:api_versions)

  def edit(conn, %{"id" => key_id}) do
    key = ApiAccounts.get_key!(conn.assigns.user.id, key_id)

    render(
      conn,
      :edit,
      key: key,
      allowed_domains: key.allowed_domains,
      changeset: ApiAccounts.change_key(key)
    )
  end

  def create(conn, _) do
    user = conn.assigns.user

    case ApiAccounts.request_key(user) do
      {:ok, key} ->
        conn =
          if key.approved do
            url = portal_url(conn, :landing)
            _ = ApiAccounts.Notifications.send_key_request_approved(user, key, url)
            put_flash(conn, :success, "Your key has been approved.")
          else
            admins = ApiAccounts.list_administrators()
            url = admin_user_url(conn, :show, conn.assigns.user.id)
            _ = ApiAccounts.Notifications.send_key_requested(admins, user, url)
            put_flash(conn, :success, "Your key has been requested.")
          end

        redirect(conn, to: portal_path(conn, :index))

      _ ->
        conn
        |> put_flash(:error, "You already have a key request pending approval.")
        |> redirect(to: portal_path(conn, :index))
    end
  end

  @valid_versions Application.get_env(:api_web, :versions)[:versions]

  def update(conn, %{"id" => key_id, "key" => values}) do
    values = validate_values(values)

    conn =
      if values == %{} do
        # ignore invalid updates
        conn
      else
        key = ApiAccounts.get_key!(conn.assigns.user.id, key_id)
        {:ok, _} = ApiAccounts.update_key(key, values)
        put_flash(conn, :info, "Key updated.")
      end

    redirect(conn, to: portal_path(conn, :index))
  end

  def request_increase(conn, %{"id" => key_id}) do
    key = ApiAccounts.get_key!(conn.assigns.user.id, key_id)
    render(conn, :increase, key: key)
  end

  def do_request_increase(conn, %{"id" => key_id, "reason" => %{"reason" => reason}}) do
    key = ApiAccounts.get_key!(conn.assigns.user.id, key_id)

    if key.rate_request_pending do
      conn
      |> put_flash(:info, "Rate limit increase request already pending.")
      |> redirect(to: portal_path(conn, :index))
    else
      {:ok, _key} = ApiAccounts.update_key(key, %{rate_request_pending: true})
      admins = ApiAccounts.list_administrators()
      url = admin_user_url(conn, :show, key.user_id)

      _email =
        ApiAccounts.Notifications.send_limit_increase_requested(
          admins,
          conn.assigns.user,
          key,
          url,
          reason
        )

      conn
      |> put_flash(:info, "Rate limit increase requested successfully.")
      |> redirect(to: portal_path(conn, :index))
    end
  end

  defp api_versions(conn, _) do
    assign(conn, :api_versions, @valid_versions)
  end

  def validate_values(values) do
    values
    |> Map.take(~w(api_version description allowed_domains))
    |> Enum.reduce(%{}, fn
      {"description", description}, acc when byte_size(description) < 256 ->
        Map.put(acc, :description, description)

      {"api_version", new_version}, acc when new_version in @valid_versions ->
        Map.put(acc, :api_version, new_version)

      {"allowed_domains", allowed_domains}, acc ->
        Map.put(acc, :allowed_domains, allowed_domains)

      _, acc ->
        acc
    end)
  end
end
