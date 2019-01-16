defmodule State.Alert.ActivePeriodTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import State.Alert.ActivePeriod
  alias Model.Alert

  @table __MODULE__

  @alerts [
    %Alert{
      id: "1"
      # no active period, matches everything
    },
    %Alert{
      id: "2",
      active_period: [
        {nil, DateTime.from_unix!(1000)},
        {DateTime.from_unix!(2000), DateTime.from_unix!(3000)},
        {DateTime.from_unix!(4000), nil}
      ]
    }
  ]

  setup do
    new(@table)
    update(@table, @alerts)
    :ok
  end

  describe "update/2" do
    test "ignores empty updates" do
      update(@table, [])
      assert size(@table) == 4
    end
  end

  describe "filter/3" do
    test "filters a list to just those that match the given ID" do
      for {unix, expected_ids} <- [
            {0, ~w(1 2)},
            {1000, ~w(1)},
            {2500, ~w(1 2)},
            {3500, ~w(1)},
            {5000, ~w(1 2)}
          ] do
        dt = DateTime.from_unix!(unix)

        actual_ids =
          @table
          |> filter(~w(1 2 3), dt)
          |> Enum.sort()

        assert actual_ids == expected_ids
      end
    end
  end
end
