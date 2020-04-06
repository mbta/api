defmodule Fetch do
  @moduledoc """
  Fetches URLs from the internet
  """

  def start_link(opts \\ []) do
    # coveralls-ignore-start
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
    # coveralls-ignore-stop
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

  def init(opts) do
    # coveralls-ignore-start
    DynamicSupervisor.init(
      strategy: :one_for_one,
      extra_arguments: [opts]
    )

    # coveralls-ignore-stop
  end
end
