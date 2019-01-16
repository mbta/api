defmodule ApiWeb.Plugs.Redirect do
  @moduledoc """
  Simple plug to assist in redirects.

  ## Example Router Usage

      get "/", ApiWeb.Redirect, to: "/other_path"

  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    conn
    |> Phoenix.Controller.redirect(opts)
    |> halt()
  end
end
