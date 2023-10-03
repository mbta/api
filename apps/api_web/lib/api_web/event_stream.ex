defmodule ApiWeb.EventStream do
  @moduledoc """

  Subscribes to controller's state module, and sends event stream data
  packets whenever the source data changes.
  """
  import Plug.Conn
  alias __MODULE__.Supervisor
  alias ApiWeb.Plugs.CheckForShutdown
  require Logger

  @enforce_keys [:conn, :pid, :timeout]
  defstruct @enforce_keys ++ [:timer]

  @typep state :: %__MODULE__{
           conn: Plug.Conn.t(),
           pid: pid,
           timeout: non_neg_integer,
           timer: reference | nil
         }

  @spec call(Plug.Conn.t(), module, map) :: Plug.Conn.t()
  def call(conn, module, _params) do
    state = initialize(conn, module)
    hibernate_loop(state)
  end

  @spec initialize(Plug.Conn.t(), module) :: state
  def initialize(conn, module, timeout \\ 30_000) do
    {:ok, pid} = Supervisor.server_subscribe(conn, module)
    Logger.debug("#{__MODULE__} connected self=#{inspect(self())} server=#{inspect(pid)}")
    Process.monitor(pid)

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      # prevent nginx from buffering the stream
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    ensure_timer(%__MODULE__{conn: conn, pid: pid, timeout: timeout})
  end

  @spec hibernate_loop(state) :: Plug.Conn.t()
  def hibernate_loop(state) do
    case receive_result(state) do
      {:continue, state} ->
        :proc_lib.hibernate(__MODULE__, :hibernate_loop, [state])

      {:close, conn} ->
        Supervisor.server_unsubscribe(state.pid)
        conn

      {:error, :closed} ->
        Supervisor.server_unsubscribe(state.pid)
        state.conn

      {:error, error} ->
        Logger.warning(
          "#{__MODULE__} unexpected error in hibernate_loop self=#{inspect(self())} server=#{inspect(state.pid)} reason=#{inspect(error)}"
        )

        Supervisor.server_unsubscribe(state.pid)
        state.conn
    end
  end

  @spec receive_result(state) :: {:continue, state} | {:close, Plug.Conn.t()} | {:error, term}
  def receive_result(%{conn: conn, pid: pid} = state) do
    receive do
      {:events, events} ->
        chunks = for {type, item} <- events, do: ["event: ", type, "\ndata: ", item, "\n\n"]

        if CheckForShutdown.running?() do
          continue(state, chunks)
        else
          close(state, chunks)
        end

      :timeout ->
        if CheckForShutdown.running?() do
          continue(state, ": keep-alive\n")
        else
          close(state)
        end

      {:error, rendered} when is_list(rendered) ->
        close(state, ["event: error\ndata: ", rendered, "\n\n"])

      {:DOWN, _ref, :process, ^pid, reason} ->
        if reason in [:normal, :shutdown] or match?({:shutdown, _}, reason),
          do: close(state),
          else: close(state, ["event: error\ndata: ", render_server_error(conn), "\n\n"])

      _ ->
        if CheckForShutdown.running?() do
          {:continue, state}
        else
          close(state)
        end
    end
  end

  @spec continue(state, Plug.Conn.body()) :: {:continue, state} | {:error, term}
  defp continue(state, chunks) do
    with {:ok, conn} <- chunk(state.conn, chunks) do
      {:continue, ensure_timer(%{state | conn: conn})}
    end
  end

  @spec close(state, Plug.Conn.body()) :: {:close, Plug.Conn.t()} | {:error, term}
  defp close(state, chunks \\ []) do
    Logger.debug("#{__MODULE__} closing self=#{inspect(self())} server=#{inspect(state.pid)}")

    with {:ok, conn} <- chunk(state.conn, chunks) do
      {:close, conn}
    end
  end

  @spec ensure_timer(state) :: state
  defp ensure_timer(%{timer: nil, timeout: timeout} = state) do
    ref = Process.send_after(self(), :timeout, timeout)
    %{state | timer: ref}
  end

  defp ensure_timer(%{timer: timer} = state) do
    :ok = Process.cancel_timer(timer, async: true)
    ensure_timer(%{state | timer: nil})
  end

  @spec render_server_error(Plug.Conn.t()) :: iodata
  defp render_server_error(%{assigns: assigns}) do
    Phoenix.View.render_to_iodata(ApiWeb.ErrorView, "500.json-api", assigns)
  end
end
