defmodule ApiWeb.Plugs.Require2Factor do
  @moduledoc """
  Plug enforcing a user to have 2fa enabled
  """

  # , only: [render: 3, put_view: 2]
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> fetch_user()
    |> authenticate(conn)
  end

  defp fetch_user(conn) do
    conn.assigns[:user]
  end

  defp authenticate(%ApiAccounts.User{totp_enabled: true}, conn), do: conn

  defp authenticate(_, conn) do
    conn
    |> put_flash(
      :error,
      "Account does not have 2-Factor Authentication enabled. Please enable before performing administrative tasks."
    )
    |> redirect(to: ApiWeb.Router.Helpers.user_path(conn, :configure_2fa))
  end
end
