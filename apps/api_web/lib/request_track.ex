defmodule RequestTrack do
  @moduledoc """
  Track the number of outstanding requests by API key.
  """
  @type key :: term
  @type server :: GenServer.server()

  # Client functions

  @spec start_link() :: {:ok, server} | {:error, term}
  @spec start_link(Keyword.t()) :: {:ok, server} | {:error, term}
  def start_link(opts \\ []) do
    gen_server_opts = Keyword.take(opts, ~w(name)a)
    GenServer.start_link(__MODULE__, opts, gen_server_opts)
  end

  @spec increment(server, key) :: :ok
  def increment(server, key) do
    :ok = GenServer.cast(server, {:monitor, self()})
    table = table(server)
    true = :ets.insert(table, {key, self()})
    :ok
  end

  @spec decrement(server) :: :ok
  def decrement(server) do
    table = table(server)
    _ = :ets.select_delete(table, [{{:_, self()}, [], [true]}])
    :ok
  end

  @spec count(server, key) :: non_neg_integer
  def count(server, key) do
    table = table(server)
    :ets.select_count(table, [{{key, :_}, [], [true]}])
  end

  defp table(server) when is_atom(server) do
    # if the server had a name, the ETS table has the same name and so we
    # don't need to ask
    :ets.whereis(server)
  end

  defp table(server) when is_pid(server) do
    GenServer.call(server, :table)
  end

  # Server callbacks
  def init(opts) do
    table_opts = [:duplicate_bag, :public, {:read_concurrency, true}, {:write_concurrency, true}]

    table =
      if name = Keyword.get(opts, :name) do
        :ets.new(name, [:named_table] ++ table_opts)
      else
        :ets.new(__MODULE__, table_opts)
      end

    {:ok, %{table: table, monitors: %{}}}
  end

  def handle_call(:table, _from, state) do
    {:reply, state.table, state}
  end

  def handle_cast({:monitor, pid}, state) do
    monitors = Map.put_new_lazy(state.monitors, pid, fn -> Process.monitor(pid) end)
    {:noreply, %{state | monitors: monitors}}
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    monitors =
      case state.monitors do
        %{^pid => ^ref} = monitors ->
          _ = :ets.select_delete(state.table, [{{:_, pid}, [], [true]}])
          Map.delete(monitors, pid)

        monitors ->
          monitors
      end

    {:noreply, %{state | monitors: monitors}}
  end
end
