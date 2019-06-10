defmodule ApiWeb.EventStream do
  @moduledoc """

  Subscribes to controller's state module, and sends event stream data
  packets whenever the source data changes.
  """
  import Plug.Conn
  alias __MODULE__.Supervisor

  @enforce_keys [:conn, :pid, :timeout]
  defstruct @enforce_keys ++ [:timer]

  @typep state :: %__MODULE__{
           conn: Plug.Conn.t(),
           pid: pid,
           timeout: non_neg_integer,
           timer: reference | nil
         }

  @spec call(Plug.Conn.t(), module, map) :: no_return
  def call(conn, module, _params) do
    state = initialize(conn, module)
    hibernate_loop(state)
  end

  @spec initialize(Plug.Conn.t(), module) :: state
  def initialize(conn, module, timeout \\ 30_000) do
    {:ok, pid} = Supervisor.server_child(conn, module)

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      # prevent nginx from buffering the stream
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    ensure_timer(%__MODULE__{conn: conn, pid: pid, timeout: timeout})
  end

  @spec hibernate_loop(state) :: no_return | {:error, term}
  def hibernate_loop(state) do
    with {:ok, state} <- receive_result(state) do
      :proc_lib.hibernate(__MODULE__, :hibernate_loop, [state])
    else
      error ->
        Supervisor.server_unsubscribe(state.pid)
        error
    end
  end

  @spec receive_result(state) :: {:ok, state} | {:error, term}
  def receive_result(state) do
    receive do
      {:events, events} ->
        chunks =
          for {type, item} <- events do
            ["event: ", type, "\ndata: ", item, "\n\n"]
          end

        update_state(state, chunk(state.conn, chunks))

      {:error, rendered} when is_list(rendered) ->
        {:error, chunk(state.conn, ["event: error\ndata: ", rendered, "\n\n"])}

      :timeout ->
        update_state(state, chunk(state.conn, ": keep-alive\n"))

      _ ->
        {:ok, state}
    end
  end

  defp update_state(state, {:ok, conn}) do
    state = ensure_timer(%{state | conn: conn})

    {:ok, state}
  end

  defp update_state(_state, {:error, _} = error) do
    error
  end

  defp ensure_timer(%{timer: nil, timeout: timeout} = state) do
    ref = Process.send_after(self(), :timeout, timeout)
    %{state | timer: ref}
  end

  defp ensure_timer(%{timer: timer} = state) do
    :ok = Process.cancel_timer(timer, async: true)
    ensure_timer(%{state | timer: nil})
  end
end
