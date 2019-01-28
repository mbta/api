defmodule ApiWeb.Plugs.Authenticate do
  @moduledoc """
  Validates API keys of incoming requests.

  If no key is provided, we create an anonymous user based on the IP address.

  If a valid key is provided in the query params or header, we create an
  authenticated user for that key.

  If an invalid key is provided, we render a 403 and halt.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [render: 3, put_view: 2]

  def init(opts), do: opts

  def call(conn, _) do
    conn
    |> api_key()
    |> add_to_logger(conn)
    |> authenticate(conn)
  end

  defp authenticate(nil, conn) do
    assign(conn, :api_user, ApiWeb.User.anon(conn_ip(conn)))
  end

  defp authenticate(key, conn) do
    case ApiAccounts.Keys.fetch_valid_key(key) do
      {:ok, %ApiAccounts.Key{} = key} ->
        user = ApiWeb.User.from_key(key)
        assign(conn, :api_user, user)

      {:error, _} ->
        conn
        |> put_status(:forbidden)
        |> put_view(ApiWeb.ErrorView)
        |> render("403.json-api", [])
        |> halt()
    end
  end

  defp api_key(%{assigns: %{api_key: api_key}}) do
    api_key
  end

  defp api_key(%{query_params: query_params} = conn) do
    case Map.get(query_params, "api_key") do
      nil -> get_api_key_from_header(conn)
      api_key -> api_key
    end
  end

  defp get_api_key_from_header(conn) do
    case get_req_header(conn, "x-api-key") do
      [] -> nil
      [api_key] -> api_key
    end
  end

  defp add_to_logger(key, _conn) when is_binary(key) do
    _ = Logger.metadata(api_key: key, ip: nil)
    key
  end

  defp add_to_logger(nil, conn) do
    _ = Logger.metadata(api_key: "anonymous", ip: conn_ip(conn))
    nil
  end

  defp conn_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [] ->
        {a, b, c, d} = conn.remote_ip
        "#{a}.#{b}.#{c}.#{d}"

      [forwarded_ip] ->
        forwarded_ip
    end
  end
end
