defmodule State.Alert.InformedEntityTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import State.Alert.InformedEntity
  alias Model.Alert

  @table __MODULE__

  @alerts [
    %Alert{
      id: "1",
      informed_entity: [%{route_type: 1, route: "Red"}]
    },
    %Alert{
      id: "2",
      informed_entity: [
        %{route_type: 1, route: "Red", stop: "place-sstat"},
        %{route_type: 1, route: "Red", stop: "place-pktrm"}
      ]
    },
    %Alert{
      id: "3",
      informed_entity: [%{stop: "place-sstat", facility: "fac"}]
    }
  ]

  setup do
    new(@table)
    update(@table, @alerts)
    :ok
  end

  describe "match/1" do
    test "can return facility alerts" do
      assert match(@table, [%{facility: "fac"}]) == ["3"]
      assert match(@table, [%{facility: "fac", stop: "place-sstat"}]) == ["2", "3"]
      assert match(@table, [%{facility: "different fac"}]) == []
    end

    test "can match multiple entities" do
      assert match(@table, [%{stop: "place-sstat"}]) == ["2", "3"]
      assert match(@table, [%{route_type: 1}]) == ["1", "2"]
    end

    test "can accept multiple matchers" do
      assert match(@table, [%{facility: "fac"}, %{route_type: 1}]) == ["1", "2", "3"]
    end

    test "can match empty values" do
      assert match(@table, [%{facility: nil}]) == ["1", "2"]
    end

    test "can matches a superset if the entity doesn't define the attributes" do
      assert match(@table, [%{route_type: 1, route: "Red", direction_id: 0}]) == ["1", "2"]
      assert match(@table, [%{route_type: 1, route: "Blue", direction_id: 0}]) == []
    end
  end
end
