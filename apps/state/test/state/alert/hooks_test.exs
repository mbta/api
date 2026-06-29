defmodule State.Alert.HooksTest do
  @moduledoc false
  use ExUnit.Case
  import State.Alert.Hooks
  alias Model.Alert

  setup do
    State.Stop.new_state([])
    State.Trip.new_state([])
    State.Route.new_state([])
    :ok
  end

  @type hook_result :: %{
          added: [Alert.informed_entity()],
          removed: [Alert.informed_entity()],
          preserved: [Alert.informed_entity()]
        }

  @spec apply_hook([Alert.informed_entity()]) :: hook_result
  @spec apply_hook(Alert.t()) :: hook_result
  defp apply_hook(informed_entities) when is_list(informed_entities) do
    apply_hook(%Alert{id: "alert1", informed_entity: informed_entities})
  end

  defp apply_hook(%Alert{} = alert) do
    assert [%Alert{informed_entity: new_informed_entities}] = pre_insert_hook(alert)

    old = MapSet.new(alert.informed_entity)
    new = MapSet.new(new_informed_entities)

    [
      added: MapSet.difference(new, old),
      removed: MapSet.difference(old, new),
      preserved: MapSet.intersection(old, new)
    ]
    |> Map.new(fn {k, ies} -> {k, normalize(ies)} end)
  end

  defp normalize(ies) do
    ies
    |> Enum.map(fn ie -> Map.replace_lazy(ie, :activities, &Enum.sort/1) end)
    |> Enum.sort()
  end

  describe "pre_insert_hook/1" do
    test "adds informed entities for alternate trips" do
      State.Trip.new_state([
        %Model.Trip{id: "trip1", alternate_route: false, route_id: "main-route"},
        %Model.Trip{id: "trip1", alternate_route: true, route_id: "alt-route1"},
        %Model.Trip{id: "trip1", alternate_route: true, route_id: "alt-route2"},
        %Model.Trip{id: "trip1", alternate_route: true, route_id: "alt-routeX", direction_id: 1}
      ])

      State.Route.new_state([
        %Model.Route{id: "main-route", type: 3},
        %Model.Route{id: "alt-route1", type: 3},
        %Model.Route{id: "alt-route2", type: 3}
      ])

      informed_entities =
        [
          %{
            stop: "bus-stop1",
            trip: "trip1",
            route: "main-route",
            direction_id: 0,
            activities: ["BOARD", "EXIT"]
          },
          %{
            stop: "bus-stop2",
            trip: "trip1",
            route: "a-different-route",
            direction_id: 0,
            activities: ["BOARD"]
          },
          %{stop: "bus-stop3", trip: "trip2", direction_id: 1}
        ]
        |> normalize()

      assert %{
               preserved: [
                 %{stop: "bus-stop3", trip: "trip2", direction_id: 1},
                 %{
                   stop: "bus-stop2",
                   trip: "trip1",
                   route: "a-different-route",
                   direction_id: 0,
                   activities: ["BOARD"]
                 }
               ],
               added: [
                 %{
                   stop: "bus-stop2",
                   trip: "trip1",
                   route: "alt-routeX",
                   direction_id: 1,
                   activities: ["BOARD"]
                 },
                 %{
                   stop: "bus-stop1",
                   trip: "trip1",
                   route: "alt-routeX",
                   direction_id: 1,
                   activities: ["BOARD", "EXIT"]
                 },
                 %{
                   stop: "bus-stop2",
                   route: "alt-route1",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD"]
                 },
                 %{
                   stop: "bus-stop2",
                   route: "alt-route2",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD"]
                 },
                 %{
                   stop: "bus-stop2",
                   route: "main-route",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD"]
                 },
                 %{
                   stop: "bus-stop1",
                   route: "alt-route1",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD", "EXIT"]
                 },
                 %{
                   stop: "bus-stop1",
                   route: "alt-route2",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD", "EXIT"]
                 },
                 %{
                   stop: "bus-stop1",
                   route: "main-route",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD", "EXIT"]
                 }
               ],
               removed: [
                 %{
                   stop: "bus-stop1",
                   trip: "trip1",
                   route: "main-route",
                   direction_id: 0,
                   activities: ["BOARD", "EXIT"]
                 }
               ]
             } = apply_hook(informed_entities)
    end
  end
end
