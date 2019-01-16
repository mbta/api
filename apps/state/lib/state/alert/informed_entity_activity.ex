defmodule State.Alert.InformedEntityActivity do
  @moduledoc """
  A flattended cache of the current alert activities as matchspecs can't be used to find if an element of a list matches
  a value as that's not a guard expressable pattern.
  """
  @table __MODULE__

  @doc """
  If no activities are specified to `filter/2`, the agency's default set of `t:Model.Alert.activity/0` are used.
  """
  @spec default_activities :: [Model.Alert.activity(), ...]
  def default_activities, do: ~w(BOARD EXIT RIDE)

  def new(table \\ @table) do
    ^table = :ets.new(table, [:named_table, :duplicate_bag, {:read_concurrency, true}])
    :ok
  end

  @doc """
  Filters `t:Model.Alert.id/0`s to only those that have at least one `t:Model.Alert.t/0` `informed_entity` `activities`
  element matching an element of `activities`

  ## Special values

  * If `activities` is empty, then `default_activities/0` is used as the default value.
  * If `activities` contains `"ALL"`, then no filtering occurs and all `alert_ids` are returned

  """
  @spec filter(atom, Enum.t(), Enum.t()) :: [Model.Alert.id()]
  def filter(table \\ @table, alert_ids, activities) do
    cond do
      # skip cost of checking `activities`
      Enum.empty?(alert_ids) ->
        alert_ids

      Enum.empty?(activities) ->
        filter(table, alert_ids, default_activities())

      # ALL wins over any specific activity
      "ALL" in activities ->
        alert_ids

      true ->
        for alert_id <- alert_ids, alert_id_has_activity?(table, activities, alert_id) do
          alert_id
        end
    end
  end

  def update(table \\ @table, alerts) do
    true = :ets.delete_all_objects(table)
    true = :ets.insert(table, alerts_to_tuples(alerts))

    :ok
  end

  defp alert_id_has_activity?(table, activities, alert_id) do
    Enum.any?(activities, &:ets.member(table, {&1, alert_id}))
  end

  defp alerts_to_tuples(alerts) do
    for %Model.Alert{id: alert_id, informed_entity: entities} <- alerts,
        entity <- entities,
        activity <- Map.get(entity, :activities, []) do
      key = {activity, alert_id}
      {key}
    end
  end
end
