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
    |> authenticate()
    |> add_to_logger()
  end

  defp authenticate(%{assigns: %{api_key: key}} = conn) when is_binary(key) do
    case ApiAccounts.Keys.fetch_valid_key(key) do
      {:ok, %ApiAccounts.Key{} = key} ->
        api_user = ApiWeb.User.from_key(key)
        assign(conn, :api_user, api_user)

      {:error, _} ->
        conn
        |> put_status(:forbidden)
        |> put_view(ApiWeb.ErrorView)
        |> render("403.json-api", [])
        |> halt()
    end
  end

  defp authenticate(conn) do
    assign(conn, :api_user, ApiWeb.User.anon(conn_ip(conn)))
  end

  defp api_key(%{assigns: %{api_key: _}} = conn) do
    conn
  end

  defp api_key(%{query_params: query_params} = conn) do
    {api_key, query_params} = Map.pop(query_params, "api_key")

    case api_key do
      nil ->
        get_api_key_from_header(conn)

      api_key ->
        params = Map.delete(conn.params, "api_key")
        conn = %{conn | query_params: query_params, params: params}
        assign(conn, :api_key, api_key)
    end
  end

  defp get_api_key_from_header(conn) do
    case get_req_header(conn, "x-api-key") do
      [api_key] -> assign(conn, :api_key, api_key)
      [] -> conn
    end
  end

  defp add_to_logger(%{assigns: %{api_key: key, api_user: _}} = conn) when is_binary(key) do
    _ = Logger.metadata(api_key: key, ip: nil)
    conn
  end

  defp add_to_logger(%{assigns: %{api_key: key}} = conn) when is_binary(key) do
    # invalid API key, also log the IP address
    _ = Logger.metadata(api_key: key, ip: conn_ip(conn))
    conn
  end

  defp add_to_logger(conn) do
    _ = Logger.metadata(api_key: "anonymous", ip: conn_ip(conn))
    conn
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
