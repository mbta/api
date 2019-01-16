defmodule State.Alert.InformedEntityActivityTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import State.Alert.InformedEntityActivity

  @table __MODULE__

  @alerts [
    # one entity, one activity
    %Model.Alert{
      id: "1",
      informed_entity: [%{activities: ["BOARD"]}]
    },
    # two entities, one activity each
    %Model.Alert{
      id: "2",
      informed_entity: [%{activities: ["BOARD"]}, %{activities: ["EXIT"]}]
    },
    # one entity, two activities
    %Model.Alert{
      id: "3",
      informed_entity: [%{activities: ["BOARD", "EXIT"]}]
    },
    %Model.Alert{
      id: "4",
      informed_entity: [%{activities: ["USING_WHEELCHAIR"]}]
    },
    # one entity, no activities
    %Model.Alert{
      id: "5",
      informed_entity: [%{facility: "fac"}]
    }
  ]
  @alert_ids Enum.map(@alerts, & &1.id)

  setup do
    new(@table)
    update(@table, @alerts)

    :ok
  end

  describe "default_activities/0" do
    test "matches v4.1 proposal" do
      assert default_activities() == ["BOARD", "EXIT", "RIDE"]
    end
  end

  describe "filter/3" do
    test "with empty alert_ids returns []" do
      alert_ids = []
      activities = ["BOARD"]

      assert Enum.empty?(filter(@table, alert_ids, activities))
    end

    test "with empty activities treats it as `default_activities/0`" do
      alert_ids = @alert_ids
      activities = []

      default_activity_alert_ids = filter(@table, alert_ids, default_activities())
      no_activity_alert_ids = filter(@table, alert_ids, activities)

      refute Enum.empty?(default_activity_alert_ids)
      refute Enum.empty?(no_activity_alert_ids)

      assert MapSet.equal?(
               MapSet.new(default_activity_alert_ids),
               MapSet.new(no_activity_alert_ids)
             )
    end

    test "with activity not on any `Model.Alert.t` `informed_entity` `activities` returns []" do
      alert_ids = @alert_ids
      activity = "USING_ESCALATOR"
      activities = [activity]

      alert_informed_entity_activities =
        for %Model.Alert{informed_entity: entities} <- @alerts,
            entity <- entities,
            entity_activity <- Map.get(entity, :activities, []),
            do: entity_activity

      refute activity in alert_informed_entity_activities
      assert Enum.empty?(filter(@table, alert_ids, activities))
    end

    test "can return alerts that match anywhere in `Model.Alert.t` `informed_entity` `activities`" do
      board_alert_ids = filter(@table, @alert_ids, ["BOARD"])

      # Only activity, one entity
      assert "1" in board_alert_ids

      # Only activity in any entity
      assert "2" in board_alert_ids

      # An activity in any entity
      assert "3" in board_alert_ids

      # Proves filtering actually works when `activities` is present and above asserts isn't just returning everything
      # with `activities`

      alerts_with_activities_count =
        Enum.count(@alerts, fn %Model.Alert{informed_entity: entities} ->
          Enum.any?(entities, &Map.has_key?(&1, :activities))
        end)

      assert Enum.count(board_alert_ids) < alerts_with_activities_count
    end

    test "can return alerts that match any of the activities" do
      board_or_exit_alert_ids = filter(@table, @alert_ids, ["BOARD", "EXIT"])

      "1" in board_or_exit_alert_ids
      "2" in board_or_exit_alert_ids
      "3" in board_or_exit_alert_ids
      "4" in board_or_exit_alert_ids
    end

    test "\"ALL\" returns all alert_ids even when other activities are present" do
      assert filter(@table, @alert_ids, ["BOARD", "ALL", "EXIT"]) == @alert_ids
    end
  end
end
