defmodule Fetch do
  @moduledoc """
  Fetches URLs from the internet
  """

  use DynamicSupervisor

  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
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
    DynamicSupervisor.start_child(__MODULE__, {Fetch.Worker, url})
  end

  @impl DynamicSupervisor
  def init(opts) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [opts]
    )
  end
end
