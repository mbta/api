defmodule State.ServiceByDate do
  @moduledoc """
  Allows finding `Model.Service.t` that are active on a given date.
  """
  use GenServer
  use Timex
  require Logger
  import Events

  @table __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def size do
    State.Helpers.safe_ets_size(@table)
  end

  def by_date(%{year: year, month: month, day: day}) do
    key = {year, month, day}
    :ets.lookup_element(@table, key, 2)
  rescue
    ArgumentError ->
      []
  end

  def valid?(service_id, %{year: year, month: month, day: day}) do
    object = {{year, month, day}, service_id}
    :ets.match_object(@table, object, 1) != :"$end_of_table"
  rescue
    ArgumentError ->
      false
  end

  def update! do
    :ok = GenServer.call(__MODULE__, :update!)
  end

  @impl GenServer
  def init(_) do
    @table = :ets.new(@table, [:named_table, :duplicate_bag, {:read_concurrency, true}])
    publish({:new_state, __MODULE__}, 0)

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
    items =
      State.Service.valid_in_future()
      |> service_with_date

    @table |> :ets.delete_all_objects()
    @table |> :ets.insert(items)

    size = length(items)

    _ =
      Logger.info(fn ->
        "Update #{__MODULE__} #{inspect(self())}: #{size} items"
      end)

    publish({:new_state, __MODULE__}, size)
    state
  end

  def service_with_date(services) do
    Enum.flat_map(services, &dates_for_service/1)
  end

  defp dates_for_service(%Model.Service{id: id} = service) do
    [
      from: Model.Service.start_date(service),
      until: Model.Service.end_date(service),
      right_open: false
    ]
    |> Interval.new()
    |> Enum.map(&NaiveDateTime.to_date/1)
    |> Enum.filter(&Model.Service.valid_for_date?(service, &1))
    |> Enum.map(&{Date.to_erl(&1), id})
  end
end
