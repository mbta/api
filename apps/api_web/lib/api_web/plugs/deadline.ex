defmodule ApiWeb.Plugs.Deadline do
  @moduledoc """
  Support for giving requests a time deadline, and allowing the request to end early if needed.
  """
  @behaviour Plug
  import Plug.Conn

  @impl Plug
  def init(_) do
    []
  end

  @impl Plug
  def call(conn, _) do
    put_private(conn, :api_web_deadline_start, current_time())
  end

  @spec set(Plug.Conn.t(), integer) :: Plug.Conn.t()
  def set(%{private: %{api_web_deadline_start: start_time}} = conn, budget) do
    deadline = start_time + budget
    put_private(conn, :api_web_deadline, deadline)
  end

  @spec check!(Plug.Conn.t()) :: :ok | no_return
  def check!(%Plug.Conn{private: %{api_web_deadline: deadline}} = conn) do
    if current_time() > deadline do
      raise __MODULE__.Error, conn: conn
    else
      :ok
    end
  end

  def check!(%Plug.Conn{}) do
    # no deadline set
    :ok
  end

  defp current_time do
    System.monotonic_time(:millisecond)
  end

  defmodule Error do
    defexception plug_status: 503, message: "deadline exceeded", conn: nil
  end
end
