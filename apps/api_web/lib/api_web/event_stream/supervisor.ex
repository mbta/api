defmodule ApiWeb.EventStream.Supervisor do
  @moduledoc """
  Supervisor for the infrastructure needed for event streaming.

  - ServerRegistry - mapping controller/params pairs to a DiffServer
  - ServerSupervisor - DynamicSupervisor for managing the children
  """
  use Supervisor

  alias ApiWeb.EventStream.{DiffServer, ServerRegistry, ServerSupervisor}

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [])
  end

  @doc """
  Subscribes the current process to the appropriate DiffServer for the given connection/module,
  starting it if it doesn't exist.
  """
  @spec server_subscribe(Plug.Conn.t(), module) :: DynamicSupervisor.on_start_child()
  def server_subscribe(conn, module) do
    case start_child(conn, module) do
      {:ok, pid} ->
        :ok = DiffServer.subscribe(pid)
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        :ok = DiffServer.subscribe(pid)
        {:ok, pid}

      {:error, _} = error ->
        error
    end
  end

  @doc "Unsubscribes the current process from the given DiffServer."
  defdelegate server_unsubscribe(pid), to: DiffServer, as: :unsubscribe

  @doc """
  Terminates all DiffServers. Assuming subscribers are monitoring their server, this is a way to
  give them advance notice that the app is shutting down (see `Canary`).
  """
  @spec terminate_servers() :: :ok
  def terminate_servers do
    ServerSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn
      {_, :restarting, _, _} -> nil
      {_, pid, _, _} -> DynamicSupervisor.terminate_child(ServerSupervisor, pid)
    end)

    :ok
  end

  defp start_child(conn, module) do
    key = server_key(conn, module)

    DynamicSupervisor.start_child(
      ServerSupervisor,
      %{
        id: DiffServer,
        start:
          {DiffServer, :start_link,
           [{conn, module, name: {:via, Registry, {ServerRegistry, key}}}]},
        restart: :temporary
      }
    )
  end

  defp server_key(conn, module) do
    params = Map.delete(conn.query_params, "api_key")
    {module, params}
  end

  # Server callbacks

  @impl Supervisor
  def init(_init_arg) do
    children = [
      {Registry, name: ServerRegistry, keys: :unique},
      {DynamicSupervisor, name: ServerSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
