defmodule ApiWeb.Plugs.CheckForShutdown do
  @moduledoc """
  Tells all requests to close with the "Connection: close" header when the system is shutting down.
  """

  import Plug.Conn

  @behaviour Plug

  @impl Plug
  def init(_opts) do
    {:ok, true}
  end

  @impl Plug
  def call(conn, _) do
    if running?() do
      conn
    else
      put_resp_header(conn, "connection", "close")
    end
  end

  @compile inline: [running?: 0]

  @spec running?() :: boolean
  @doc """
  Return a boolean indicating whether the system is still running.
  """
  def running? do
    :persistent_term.get(__MODULE__, true)
  end

  @spec started() :: :ok
  @doc """
  Mark the system as started.

  Not required, but improves the performance in the "is-running" case.

  We can't do this in `init/1`, because that might happen at compile-time instead of runtime.
  """
  def started do
    :persistent_term.put(__MODULE__, true)

    :ok
  end

  @spec shutdown() :: :ok
  @doc """
  Mark the system as shutting down, so that all connections are closed.
  """
  def shutdown do
    :persistent_term.put(__MODULE__, false)

    :ok
  end

  # test-only function for re-setting the persistent_term state
  @doc false
  def reset do
    :persistent_term.erase(__MODULE__)
  end
end
