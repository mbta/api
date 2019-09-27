defmodule State.Alert.HooksTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import State.Alert.Hooks

  @alert %Model.Alert{
    id: "alert1",
    informed_entity: [
      %{
        route_type: 3,
        route: "1",
        direction_id: 0,
        stop: "place-cool",
        activities: ["BOARD", "RIDE"]
      },
      %{
        route_type: 3,
        route: "1",
        direction_id: 0,
        stop: "place-cool",
        activities: ["EXIT"]
      }
    ],
    severity: 1
  }

  test "pre_insert_hook/1 merges informed entities" do
    [alert] = pre_insert_hook(@alert)
    ie = Map.get(alert, :informed_entity)
    assert is_list(ie)
    assert length(ie) == 1
    assert length(ie |> hd |> Map.get(:activities)) == 3
  end
end
