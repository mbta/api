defmodule ApiWeb.Plugs.FetchUser do
  @moduledoc """
  Fetches a user_id stored in the session and assigns the user.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _) do
    case get_session(conn, :user_id) do
      nil ->
        conn

      user_id ->
        user = ApiAccounts.get_user!(user_id)
        assign(conn, :user, user)
    end
  end
end
