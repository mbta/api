defmodule ApiWeb.Plugs.RequestTrack do
  @moduledoc """
  Track the number of concurrent requests made by a given API key or IP address.
  """
  @behaviour Plug
  import Plug.Conn, only: [register_before_send: 2]

  @impl Plug
  def init(opts) do
    Keyword.fetch!(opts, :name)
  end

  @impl Plug
  @doc """
  Track the API user, and decrement the count before sending.

  We increment the count when we're initially called, and set up a callback
  to decrement the count before the response is sent.
  """
  def call(conn, table_name) do
    key = conn.assigns.api_user
    RequestTrack.increment(table_name, key)
    _ = Logger.metadata(concurrent: RequestTrack.count(table_name, key))

    register_before_send(conn, fn conn ->
      RequestTrack.decrement(table_name)
      conn
    end)
  end
end
