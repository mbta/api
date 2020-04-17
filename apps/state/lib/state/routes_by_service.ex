defmodule State.RoutesByService do
  @moduledoc """
  Allows finding `Model.Route.t` that are active on a given date.
  """
  use Timex
  require Logger
  use Events.Server
  import Events
  import State.Helpers

  @table __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def size do
    safe_ets_size(@table)
  end

  def for_service_id(service_id) do
    @table |> :ets.match_object({{service_id, :_}, :_}) |> do_get_routes()
  end

  def for_service_id_and_types(service_id, route_types) do
    @table
    |> :ets.select(
      for(
        type <- route_types,
        do: {{{service_id, type}, :_}, [], [:"$_"]}
      )
    )
    |> do_get_routes()
  end

  defp do_get_routes(ets_items) do
    case ets_items do
      [] ->
        []

      [{_, routes} | _] ->
        routes
    end
  end

  def update! do
    :ok = GenServer.call(__MODULE__, :update!)
  end

  @impl Events.Server
  def handle_event(_, _, _, state) do
    {_, _, state, _} = handle_call(:update!, nil, state)
    {:noreply, state, :hibernate}
  end

  @impl GenServer
  def init(_) do
    @table = :ets.new(@table, [:named_table, :duplicate_bag, {:read_concurrency, true}])
    publish({:new_state, __MODULE__}, 0)

    subscriptions = [
      {:new_state, State.Route},
      {:new_state, State.Trip},
      {:new_state, State.Service}
    ]

    for subscription <- subscriptions do
      subscribe(subscription)
    end

    if State.Service.size() > 0 do
      send(self(), :update)
    end

    {:ok, nil}
  end

  @impl GenServer
  def handle_call(:update!, _from, state) do
    state = update_state(state)
    {:reply, :ok, state, :hibernate}
  end

  @impl GenServer
  def handle_info(:update, state) do
    state = update_state(state)
    {:noreply, state, :hibernate}
  end

  def update_state(state) do
    trips = State.Trip.all()
    routes = Map.new(State.Route.all(), fn x -> {x.id, x} end)

    items =
      trips
      |> Enum.group_by(fn x ->
        {x.service_id, Map.get(routes, x.route_id, %Model.Route{}).type}
      end)
      |> Enum.map(fn {x, y} -> {x, Enum.map(y, fn x -> x.route_id end)} end)

    :ets.delete_all_objects(@table)
    :ets.insert(@table, items)

    size = length(items)

    _ =
      Logger.info(fn ->
        "Update #{__MODULE__} #{inspect(self())}: #{size} items"
      end)

    publish({:new_state, __MODULE__}, size)
    state
  end
end
