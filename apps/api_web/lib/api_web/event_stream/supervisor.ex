defmodule ApiWeb.EventStream.Supervisor do
  @moduledoc """
  Supervisor for the infrastructure needed for event streaming.

  - ServerRegistry - mapping controller/params pairs to an EventStream.Server
  - ServerSupervisor - DynamicSupervisor for managing the children
  """
  def start_link do
    Supervisor.start_link(
      [
        {Registry, name: ApiWeb.EventStream.ServerRegistry, keys: :unique},
        {DynamicSupervisor, name: ApiWeb.EventStream.ServerSupervisor, strategy: :one_for_one}
      ],
      strategy: :one_for_all
    )
  end

  @doc """
  Returns a {:ok, pid} tuple for an EventStream.Server for the given connection/module.

  If one already exists, the same one will be returned.
  """
  def server_child(conn, module) do
    case start_child(conn, module) do
      {:ok, pid} ->
        :ok = ApiWeb.EventStream.DiffServer.subscribe(pid)
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        :ok = ApiWeb.EventStream.DiffServer.subscribe(pid)
        {:ok, pid}

      {:error, _} = error ->
        error
    end
  end

  @doc "Unsubscribes the current pid from the given Server pid."
  defdelegate server_unsubscribe(pid), to: ApiWeb.EventStream.DiffServer, as: :unsubscribe

  defp start_child(conn, module) do
    key = server_key(conn, module)

    DynamicSupervisor.start_child(
      ApiWeb.EventStream.ServerSupervisor,
      %{
        id: ApiWeb.EventStream.DiffServer,
        start:
          {ApiWeb.EventStream.DiffServer, :start_link,
           [{conn, module, name: {:via, Registry, {ApiWeb.EventStream.ServerRegistry, key}}}]},
        restart: :temporary
      }
    )
  end

  defp server_key(conn, module) do
    params = Map.delete(conn.query_params, "api_key")
    {module, params}
  end
end
