defmodule ApiWeb.Plugs.Version do
  @moduledoc """
  Sets the API version to use for the request.

  API keys have a version stored in the database. Anonymous users have a
  static default. All users can override the default by sending the
  `MBTA-Version` header.

  Assigns `:api_version` to a value from the api_web/versions/versions configuration variable.
  """
  import Plug.Conn
  @behaviour Plug

  @assign_key :api_version
  @header_name "mbta-version"
  @config Application.get_env(:api_web, :versions)
  @valid_versions @config[:versions]

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    conn
    |> assign_from_header()
    |> assign_from_user()
    |> logger_metadata()
  end

  defp assign_from_header(conn) do
    case get_req_header(conn, @header_name) do
      [version] when version in @valid_versions ->
        assign_version(conn, version)

      _ ->
        conn
    end
  end

  defp assign_from_user(%{assigns: %{@assign_key => _}} = conn) do
    conn
  end

  defp assign_from_user(conn) do
    assign_version(conn, conn.assigns.user.version)
  end

  defp logger_metadata(conn) do
    :ok = Logger.metadata([{@assign_key, Map.get(conn.assigns, @assign_key)}])
    conn
  end

  defp assign_version(conn, version) do
    assign(conn, @assign_key, version)
  end
end
