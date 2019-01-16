defmodule State.Alert.ActivePeriod do
  @moduledoc """
  A flattened cache of the current alerts, for easier querying of active period
  """
  use Recordable, [:id, :start, :stop]
  alias Model.Alert

  @table __MODULE__

  def new(table \\ @table) do
    ^table = :ets.new(table, [:named_table, :duplicate_bag, {:read_concurrency, true}])
    :ok
  end

  def update(table \\ @table, alerts)

  def update(table, [_ | _] = alerts) do
    flattened = Enum.flat_map(alerts, &flatten/1)
    :ok = update(table, [])
    true = :ets.delete_all_objects(table)
    true = :ets.insert(table, flattened)
    :ok
  end

  def update(_table, []) do
    # ignore empty updates
    :ok
  end

  def size(table \\ @table) do
    State.Helpers.safe_ets_size(table)
  end

  def filter(table \\ @table, ids, dt)

  def filter(_table, [], _dt) do
    []
  end

  def filter(table, ids, %DateTime{} = dt) when is_list(ids) do
    unix = DateTime.to_unix(dt)

    query = [{:>=, unix, :"$1"}, {:<, unix, :"$2"}]

    selectors =
      for id <- ids do
        {
          {id, :"$1", :"$2"},
          query,
          [id]
        }
      end

    :ets.select(table, selectors)
  end

  defp flatten(%Alert{active_period: []} = alert) do
    flatten(%{alert | active_period: [{nil, nil}]})
  end

  defp flatten(%Alert{id: id, active_period: active_period}) do
    for {start, stop} <- active_period do
      flatten_row(id, start, stop)
    end
  end

  defp flatten_row(id, nil, nil), do: {id, 0, :max}
  defp flatten_row(id, nil, stop), do: {id, 0, DateTime.to_unix(stop)}
  defp flatten_row(id, start, nil), do: {id, DateTime.to_unix(start), :max}
  defp flatten_row(id, start, stop), do: {id, DateTime.to_unix(start), DateTime.to_unix(stop)}
end
