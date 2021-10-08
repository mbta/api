defmodule ApiWeb.Plugs.ExperimentalFeatures do
  @moduledoc """
  Allows a requestor to opt into experimental features in the API.

  By including the `x-enable-experimental-features: true` header, a user
  can opt into data and features that might change without prior warning
  or without a backwards-compatible fallback.

  This places a `:experimental_features_enabled?` in the conn's assigns.
  """
  @behaviour Plug
  import Plug.Conn

  @impl Plug
  def init(options) do
    options
  end

  @impl Plug
  def call(conn, _) do
    enabled? = get_req_header(conn, "x-enable-experimental-features") == ["true"]
    assign(conn, :experimental_features_enabled?, enabled?)
  end
end
