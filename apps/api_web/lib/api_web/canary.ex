defmodule ApiWeb.Canary do
  @moduledoc """
  Process that calls a function when it is terminated due to a shutdown. Intended to be placed
  after the Endpoint in the same supervision tree, allowing processes to be notified
  that the app is shutting down so they can cleanly close their HTTP connections.
  """

  use GenServer

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args \\ []) do
    notify_fn = Keyword.get(args, :notify_fn, &__MODULE__.notify/0)

    GenServer.start_link(__MODULE__, notify_fn, [])
  end

  @impl true
  def init(notify_fn) when not is_function(notify_fn, 0),
    do: {:stop, "expect function/0 for notify_fn, got #{inspect(notify_fn)}"}

  def init(notify_fn) do
    Process.flag(:trap_exit, true)
    ApiWeb.Plugs.CheckForShutdown.started()
    {:ok, notify_fn}
  end

  @impl true
  def terminate(:shutdown, notify_fn) when is_function(notify_fn, 0), do: notify_fn.()
  def terminate({:shutdown, _reason}, notify_fn) when is_function(notify_fn, 0), do: notify_fn.()
  def terminate(_, _), do: :ok

  @spec notify() :: :ok
  def notify do
    Logger.info("#{__MODULE__} notified about shutdown")
    ApiWeb.Plugs.CheckForShutdown.shutdown()
    ApiWeb.EventStream.Supervisor.terminate_servers()
    Logger.info("#{__MODULE__} finished notifications")

    :ok
  end
end
