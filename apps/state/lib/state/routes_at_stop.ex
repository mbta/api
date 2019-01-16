defmodule State.RoutesAtStop do
  @moduledoc """
  Allows finding all routes that pass through a stop.
  """
  use Events.Server
  require Logger

  import State.Logger
  import State.Helpers

  alias State.{Route, Schedule, Shape, Trip}

  @table __MODULE__
  @subscriptions [
    {:new_state, Route},
    {:new_state, Trip},
    {:new_state, Shape},
    {:new_state, Schedule}
  ]

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def by_family_stops(stop_ids, opts \\ []) when is_list(stop_ids) do
    stop_ids
    |> State.Stop.by_family_ids()
    |> Enum.map(& &1.id)
    |> by_stops_and_direction(opts)
  end

  def by_stop_and_direction(stop_id, opts \\ []) do
    by_stops_and_direction([stop_id], opts)
  end

  def by_stops_and_direction(stop_ids, opts \\ []) when is_list(stop_ids) do
    direction_id = Keyword.get(opts, :direction_id, :_)

    selectors =
      for stop_id <- Enum.uniq(stop_ids),
          service_id <- Keyword.get(opts, :service_ids, [:_]) do
        {{stop_id, direction_id, service_id, :"$1"}, [], [:"$1"]}
      end

    @table
    |> :ets.select(selectors)
    |> Enum.uniq()
  end

  def by_stop(stop_id), do: by_stop_and_direction(stop_id, [])

  def size do
    safe_ets_size(@table)
  end

  def update! do
    :ok = GenServer.call(__MODULE__, :update!)
  end

  @impl Events.Server
  def handle_event(_, _, _, state) do
    state = update_state(state)
    {:noreply, state, :hibernate}
  end

  @impl GenServer
  def init(_) do
    Enum.each(@subscriptions, &subscribe/1)
    @table = :ets.new(@table, [:named_table, :duplicate_bag, {:read_concurrency, true}])
    publish({:new_state, __MODULE__}, 0)

    if Schedule.size() > 0 do
      send(self(), :update)
    end

    {:ok, nil}
  end

  @impl GenServer
  def handle_call(:update!, _from, state) do
    state = update_state(state)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info(:update, state) do
    state = update_state(state)
    {:noreply, state, :hibernate}
  end

  defp update_state(state) do
    debug_time(
      fn ->
        items =
          Trip.all()
          |> Enum.group_by(& &1.route_id)
          |> Enum.flat_map(&do_gather_route/1)

        _ =
          if items != [] do
            true = :ets.delete_all_objects(@table)
            true = :ets.insert(@table, items)
          end
      end,
      # no cover
      fn milliseconds -> "handle_event #{__MODULE__} took #{milliseconds}ms" end
    )

    new_size = size()
    _ = Logger.info(fn -> "Update #{__MODULE__}: #{new_size} items" end)
    publish({:new_state, __MODULE__}, new_size)
    state
  end

  defp do_gather_route({route_id, trips}) do
    trips
    |> Stream.reject(&ignore_trip_for_route?/1)
    |> Enum.group_by(&{&1.direction_id, &1.service_id})
    |> Stream.flat_map(&do_gather_stops_on_trips/1)
    |> Stream.uniq()
    |> Stream.map(fn {stop_id, direction_id, service_id} ->
      {stop_id, direction_id, service_id, route_id}
    end)
  end

  defp do_gather_stops_on_trips({{direction_id, service_id}, trips}) do
    trips
    |> Enum.map(& &1.id)
    |> Schedule.by_trip_ids()
    |> Stream.map(fn schedule ->
      {schedule.stop_id, direction_id, service_id}
    end)
  end
end
