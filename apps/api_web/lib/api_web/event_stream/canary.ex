defmodule ApiWeb.EventStream.Canary do
  @moduledoc """
  Process that calls a function when it is terminated due to a shutdown. Intended to be placed
  after the Endpoint in the same supervision tree, allowing EventStream processes to be notified
  that the app is shutting down so they can cleanly close their HTTP connections.
  """

  use GenServer

  @default_notify_fn &ApiWeb.EventStream.Supervisor.terminate_servers/0

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args \\ []) do
    notify_fn =
      case Keyword.fetch(args, :notify_fn) do
        {:ok, fun} when is_function(fun, 0) ->
          fun

        {:ok, not_fun} ->
          raise ArgumentError, "expect function/0 for notify_fn, got #{inspect(not_fun)}"

        _ ->
          @default_notify_fn
      end

    GenServer.start_link(__MODULE__, notify_fn, [])
  end

  @impl true
  def init(notify_fn) do
    Process.flag(:trap_exit, true)
    {:ok, notify_fn}
  end

  @impl true
  def terminate(:shutdown, notify_fn) when is_function(notify_fn), do: notify_fn.()
  def terminate({:shutdown, _reason}, notify_fn), do: notify_fn.()
  def terminate(_, _), do: :ok
end
