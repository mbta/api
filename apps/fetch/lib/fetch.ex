defmodule Fetch do
  @moduledoc """
  Fetches URLs from the internet
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def fetch_url(url, opts \\ []) do
    pid =
      case GenServer.whereis(Fetch.Worker.via_tuple(url)) do
        nil ->
          case start_child(url) do
            {:ok, pid} -> pid
            {:error, {:already_started, pid}} -> pid
          end

        pid ->
          pid
      end

    Fetch.Worker.fetch_url(pid, opts)
  end

  def start_child(url) do
    Supervisor.start_child(__MODULE__, [url])
  end

  def init(opts) do
    children = [
      worker(Fetch.Worker, [opts], restart: :temporary)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end
end
