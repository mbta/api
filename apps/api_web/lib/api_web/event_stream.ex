defmodule ApiWeb.EventStream do
  @moduledoc """

  Subscribes to controller's state module, and sends event stream data
  packets whenever the source data changes.
  """
  import Plug.Conn
  alias __MODULE__.Supervisor

  @type state :: {Plug.Conn.t(), pid}

  @spec call(Plug.Conn.t(), module, map) :: Plug.Conn.t()
  def call(conn, module, _params) do
    state = initialize(conn, module)
    event_stream_loop(&event_stream_loop/2, state)
  end

  @spec initialize(Plug.Conn.t(), module) :: state
  def initialize(conn, module) do
    {:ok, pid} = Supervisor.server_child(conn, module)

    conn =
      conn
      |> put_resp_header("content-type", "text/event-stream")
      # prevent nginx from buffering the stream
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    {conn, pid}
  end

  @spec event_stream_loop(loop, state) :: Plug.Conn.t() when loop: (loop, state -> Plug.Conn.t())
  def event_stream_loop(next_call, {conn, pid} = state) do
    with {:ok, new_conn} <- receive_result(state) do
      next_call.(next_call, {new_conn, pid})
    else
      _ ->
        Supervisor.server_unsubscribe(pid)
        conn
    end
  end

  @spec receive_result(state) ::
          chunk_result
          | {:error, chunk_result}
        when chunk_result: {:ok, Plug.Conn.t()} | {:error, term}

  def receive_result({conn, _pid} = state, timeout \\ 30_000) do
    receive do
      {:events, events} ->
        chunks =
          for {type, item} <- events do
            ["event: ", type, "\ndata: ", item, "\n\n"]
          end

        chunk(conn, chunks)

      {:error, rendered} when is_list(rendered) ->
        {:error, chunk(conn, ["event: error\ndata: ", rendered, "\n\n"])}

      _ ->
        receive_result(state, timeout)
    after
      timeout ->
        chunk(conn, ": keep-alive\n")
    end
  end
end
