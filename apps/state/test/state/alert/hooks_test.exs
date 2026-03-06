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

  @spec get_computed_informed_entities([Alert.informed_entity()]) ::
          %{
            added: [Alert.informed_entity()],
            removed: [Alert.informed_entity()],
            preserved: [Alert.informed_entity()]
          }
  defp get_computed_informed_entities(informed_entities) when is_list(informed_entities) do
    get_computed_informed_entities(%Alert{id: "alert1", informed_entity: informed_entities})
  end

  @spec get_computed_informed_entities(Alert.t()) :: %{
          added: [Alert.informed_entity()],
          removed: [Alert.informed_entity()],
          preserved: [Alert.informed_entity()]
        }
  defp get_computed_informed_entities(%Alert{} = alert) do
    informed_entities = alert.informed_entity

    assert [%Alert{informed_entity: new_informed_entities}] = pre_insert_hook(alert)

    new_informed_entities = MapSet.new(new_informed_entities)
    informed_entities = MapSet.new(informed_entities)

    [
      added: MapSet.difference(new_informed_entities, informed_entities),
      removed: MapSet.difference(informed_entities, new_informed_entities),
      preserved: MapSet.intersection(new_informed_entities, informed_entities)
    ]
    |> Map.new(fn {k, ies} -> {k, normalize(ies)} end)
  end

  defp normalize(ies) do
    ies
    |> Enum.map(fn ie -> Map.replace_lazy(ie, :activities, &Enum.sort/1) end)
    |> Enum.sort()
  end

  describe "pre_insert_hook/1" do
    test "adds informed entities for parent stations" do
      State.Stop.new_state([
        %Model.Stop{id: "child-stop1", parent_station: "parent-stationA"},
        %Model.Stop{id: "child-stop2", parent_station: "parent-stationB"},
        %Model.Stop{id: "child-stop3", parent_station: "parent-stationB"},
        %Model.Stop{id: "parentless-stop"}
      ])

      informed_entities =
        [
          %{stop: "child-stop1"},
          %{stop: "child-stop2"},
          %{stop: "child-stop3"},
          %{stop: "parentless-stop"}
        ]
        |> normalize()

      assert %{
               preserved: ^informed_entities,
               added: [%{stop: "parent-stationA"}, %{stop: "parent-stationB"}]
             } = get_computed_informed_entities(informed_entities)
    end

    test "merges child informed entities' activities for parent station informed entities," <>
           " and does *not* merge activities for pre-existing child stop informed entities" do
      State.Stop.new_state([
        %Model.Stop{id: "child-stop1", parent_station: "parent-stationA"},
        %Model.Stop{id: "child-stop2", parent_station: "parent-stationA"},
        %Model.Stop{id: "child-stop3", parent_station: "parent-stationB"},
        %Model.Stop{id: "child-stop4", parent_station: "parent-stationB"},
        %Model.Stop{id: "child-stop5", parent_station: "parent-stationC"},
        %Model.Stop{id: "parentless-stop"}
      ])

      informed_entities =
        [
          %{
            stop: "child-stop1",
            route: "route1",
            activities: ["BOARD", "EXIT", "USING_WHEELCHAIR"]
          },
          %{stop: "child-stop1", route: "route2", activities: ["BOARD"]},
          %{stop: "child-stop2", route: "route1", activities: ["BOARD", "EXIT", "RIDE"]},
          %{stop: "child-stop3", activities: ["BOARD"], route: "route1", trip: "trip1"},
          %{stop: "child-stop4", activities: ["EXIT"], route: "route1", trip: "trip1"},
          %{stop: "child-stop4", activities: ["RIDE"], route: "route1", trip: "trip2"},
          %{stop: "child-stop4", activities: ["RIDE"], route: "route2", trip: "trip1"},
          %{stop: "child-stop5", activities: ["USING_ESCALATOR"]},
          %{stop: "parentless-stop", activities: ["BRINGING_BIKE", "STORE_BIKE"]}
        ]
        |> normalize()

      assert %{
               preserved: ^informed_entities,
               added: [
                 %{stop: "parent-stationC", activities: ["USING_ESCALATOR"]},
                 %{stop: "parent-stationA", route: "route2", activities: ["BOARD"]},
                 %{
                   stop: "parent-stationA",
                   route: "route1",
                   activities: ["BOARD", "EXIT", "RIDE", "USING_WHEELCHAIR"]
                 },
                 %{
                   stop: "parent-stationB",
                   activities: ["BOARD", "EXIT"],
                   route: "route1",
                   trip: "trip1"
                 },
                 %{stop: "parent-stationB", activities: ["RIDE"], route: "route1", trip: "trip2"},
                 %{stop: "parent-stationB", activities: ["RIDE"], route: "route2", trip: "trip1"}
               ]
             } = get_computed_informed_entities(informed_entities)
    end

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
             } = get_computed_informed_entities(informed_entities)
    end

    test "adds Cartesian product of computed informed entities for parent stations X alternate trips" do
      State.Stop.new_state([
        %Model.Stop{id: "busway-berth1", parent_station: "parent-stationA"},
        %Model.Stop{id: "busway-berth2", parent_station: "parent-stationA"}
      ])

      State.Trip.new_state([
        %Model.Trip{id: "trip1", alternate_route: false, route_id: "main-route"},
        %Model.Trip{id: "trip1", alternate_route: true, route_id: "alt-route"}
      ])

      State.Route.new_state([
        %Model.Route{id: "main-route", type: 3},
        %Model.Route{id: "alt-route", type: 3}
      ])

      informed_entities =
        [
          %{
            stop: "busway-berth1",
            trip: "trip1",
            route: "main-route",
            direction_id: 0,
            activities: ["BOARD", "EXIT"]
          },
          %{
            stop: "busway-berth2",
            trip: "trip1",
            route: "main-route",
            direction_id: 0,
            activities: ["BOARD", "USING_WHEELCHAIR"]
          }
        ]
        |> normalize()

      assert %{
               preserved: [],
               added: [
                 %{
                   stop: "busway-berth1",
                   route: "alt-route",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD", "EXIT"]
                 },
                 %{
                   stop: "busway-berth1",
                   route: "main-route",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD", "EXIT"]
                 },
                 %{
                   stop: "parent-stationA",
                   route: "alt-route",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD", "EXIT", "USING_WHEELCHAIR"]
                 },
                 %{
                   stop: "parent-stationA",
                   route: "main-route",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD", "EXIT", "USING_WHEELCHAIR"]
                 },
                 %{
                   stop: "busway-berth2",
                   route: "alt-route",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD", "USING_WHEELCHAIR"]
                 },
                 %{
                   stop: "busway-berth2",
                   route: "main-route",
                   direction_id: nil,
                   route_type: 3,
                   trip: "trip1",
                   activities: ["BOARD", "USING_WHEELCHAIR"]
                 }
               ],
               removed: [
                 %{
                   stop: "busway-berth1",
                   route: "main-route",
                   direction_id: 0,
                   trip: "trip1",
                   activities: ["BOARD", "EXIT"]
                 },
                 %{
                   stop: "busway-berth2",
                   route: "main-route",
                   direction_id: 0,
                   trip: "trip1",
                   activities: ["BOARD", "USING_WHEELCHAIR"]
                 }
               ]
             } = get_computed_informed_entities(informed_entities)
    end

    test "handles specific case from bugfix ticket" do
      # https://app.asana.com/1/15492006741476/project/584764604969369/task/1213450825693783?focus=true

      State.Stop.new_state([
        %Model.Stop{id: "BNT-0000", parent_station: "place-north"},
        %Model.Stop{id: "WR-0045-S", parent_station: "place-mlmnl"},
        %Model.Stop{id: "WR-0053-S", parent_station: "place-ogmnl"}
      ])

      assert [alert] = Parse.Alerts.parse(alerts_enhanced_json_excerpt())

      informed_entities = normalize(alert.informed_entity)

      expected_new_informed_entities =
        [
          %{
            stop: "place-mlmnl",
            activities: ["BOARD", "EXIT", "RIDE"],
            route: "CR-Haverhill",
            direction_id: 1,
            route_type: 2
          },
          %{
            stop: "place-mlmnl",
            activities: ["BOARD", "EXIT", "RIDE"],
            route: "CR-Haverhill",
            direction_id: 0,
            route_type: 2
          },
          %{
            stop: "place-north",
            activities: ["BOARD", "EXIT", "RIDE"],
            route: "CR-Haverhill",
            direction_id: 1,
            route_type: 2
          },
          %{
            stop: "place-north",
            activities: ["BOARD", "EXIT", "RIDE"],
            route: "CR-Haverhill",
            direction_id: 0,
            route_type: 2
          },
          %{
            stop: "place-ogmnl",
            activities: ["BOARD", "EXIT", "RIDE"],
            route: "CR-Haverhill",
            direction_id: 1,
            route_type: 2
          },
          %{
            stop: "place-ogmnl",
            activities: ["BOARD", "EXIT", "RIDE"],
            route: "CR-Haverhill",
            direction_id: 0,
            route_type: 2
          }
        ]
        |> normalize()

      assert %{
               preserved: ^informed_entities,
               added: ^expected_new_informed_entities
             } = get_computed_informed_entities(alert)
    end
  end

  defp alerts_enhanced_json_excerpt do
    ~S"""
    {
      "entity": [
        {
          "id": "1000217",
          "alert": {
            "cause": "UNKNOWN_CAUSE",
            "effect": "REDUCED_SERVICE",
            "severity": 7,
            "active_period": [
              {
                "start": 1772415300,
                "end": 1772697600
              }
            ],
            "duration_certainty": "KNOWN",
            "cause_detail": "UNKNOWN_CAUSE",
            "effect_detail": "SUSPENSION",
            "informed_entity": [
              {
                "direction_id": 1,
                "stop_id": "BNT-0000",
                "route_id": "CR-Haverhill",
                "route_type": 2,
                "agency_id": "1",
                "activities": [
                  "EXIT",
                  "RIDE"
                ]
              },
              {
                "direction_id": 1,
                "stop_id": "WR-0045-S",
                "route_id": "CR-Haverhill",
                "route_type": 2,
                "agency_id": "1",
                "activities": [
                  "BOARD",
                  "EXIT",
                  "RIDE"
                ]
              },
              {
                "direction_id": 1,
                "stop_id": "WR-0053-S",
                "route_id": "CR-Haverhill",
                "route_type": 2,
                "agency_id": "1",
                "activities": [
                  "BOARD",
                  "RIDE"
                ]
              },
              {
                "direction_id": 0,
                "stop_id": "BNT-0000",
                "route_id": "CR-Haverhill",
                "route_type": 2,
                "agency_id": "1",
                "activities": [
                  "BOARD",
                  "RIDE"
                ]
              },
              {
                "direction_id": 0,
                "stop_id": "WR-0045-S",
                "route_id": "CR-Haverhill",
                "route_type": 2,
                "agency_id": "1",
                "activities": [
                  "BOARD",
                  "EXIT",
                  "RIDE"
                ]
              },
              {
                "direction_id": 0,
                "stop_id": "WR-0053-S",
                "route_id": "CR-Haverhill",
                "route_type": 2,
                "agency_id": "1",
                "activities": [
                  "EXIT",
                  "RIDE"
                ]
              }
            ],
            "last_modified_timestamp": 1772415513,
            "severity_level": "SEVERE",
            "header_text": {
              "translation": [
                {
                  "text": "Haverhill Line: service suspended between North Station and Oak Grove today.",
                  "language": "en"
                }
              ]
            },
            "description_text": {
              "translation": [
                {
                  "text": "Affected stations:\r\nNorth Station\r\nMalden Center\r\nOak Grove",
                  "language": "en"
                }
              ]
            },
            "service_effect_text": {
              "translation": [
                {
                  "text": "Suspension of service on Haverhill Line",
                  "language": "en"
                }
              ]
            },
            "created_timestamp": 1772415356,
            "alert_lifecycle": "NEW"
          }
        }
      ]
    }
    """
  end
end
