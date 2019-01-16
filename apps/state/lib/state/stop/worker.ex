defmodule State.Stop.Worker do
  @moduledoc """
  A worker that allows calculating the `State.Stop.List.around/4`, which can take awhile, so there's more than one
  worker to handle the load.
  """

  use GenServer
  require Logger

  @timeout 60_000

  def start_link(worker_id) do
    GenServer.start_link(__MODULE__, nil, name: via_tuple(worker_id))
  end

  def stop(worker_id) do
    GenServer.stop(via_tuple(worker_id))
  end

  def new_state(worker_id, list_of_stops) do
    :ok = GenServer.call(via_tuple(worker_id), {:new_state, list_of_stops}, @timeout)
  end

  def around(worker_id, latitude, longitude, radius \\ 0.01) do
    GenServer.call(via_tuple(worker_id), {:around, latitude, longitude, radius})
  end

  defp via_tuple(worker_id) do
    {:via, Registry, {State.Stop.Registry, worker_id}}
  end

  # Server callbacks
  def init(_) do
    initial_stops = State.Stop.Cache.all()
    {:ok, State.Stop.List.new(initial_stops)}
  end

  def handle_call({:new_state, list_of_stops}, _from, _state) do
    _ = Logger.info("Update State.Stop.Worker #{inspect(self())}: #{length(list_of_stops)} stops")
    {:reply, :ok, State.Stop.List.new(list_of_stops)}
  end

  def handle_call({:around, latitude, longitude, radius}, _from, l) do
    {:reply, State.Stop.List.around(l, latitude, longitude, radius), l}
  end
end
