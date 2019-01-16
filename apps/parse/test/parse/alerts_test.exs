defmodule Parse.AlertsTest do
  use ExUnit.Case, async: true
  use Timex

  alias Model.Alert

  import Parse.Alerts

  test "can parse a basic JSON string" do
    body = ~s({
      "alerts": [
        {
          "active_period": [
            {
              "start": 1463992200
            }
          ],
          "informed_entity": [
              {
                "route_type": 2,
                "mode_name": "Commuter Rail",
                "route_id": "CR-Fairmount",
                "route_name": "Fairmount Line"
              },
              {
                "mode_name": "Bus",
                "route_id": "5",
                "route_name": "5",
                "stop_id": "10032",
                "stop_name": "E 1st St opp O St",
                "trip": {
                  "direction_id": 1,
                  "trip_id": "trip"
                }
              }
          ],
          "alert_lifecycle": "NEW",
          "banner_text": [
            {
              "translation": {
                "language": "en",
                "text": "Banner Text!"
              }
            }
          ],
          "cause": "UNKNOWN_CAUSE",
          "created_timestamp": 1460656996,
          "description_text": [
            {
              "translation": {
                "language": "en",
                "text": "description"
              }
            }
          ],
          "effect": "MODIFIED_SERVICE",
          "effect_detail": "SCHEDULE_CHANGE",
          "header_text": [
            {
              "translation": {
                "language": "en",
                "text": "New Commuter Rail schedules become effective today, Monday, May 23rd. To view updated schedules, go to mbta.com."
              }
            }
          ],
          "id": "122425",
          "last_modified_timestamp": 1463995626,
          "service_effect_text": [
            {
              "translation": {
                "language": "en",
                "text": "Commuter Rail schedule change"
              }
            }
          ],
          "severity": 3,
          "short_header_text": [
            {
              "translation": {
                "language": "en",
                "text": "New Commuter Rail schedules become effective today, Monday, May 23rd. To view updated schedules, go to mbta.com."
              }
            }
          ],
          "timeframe_text": [
            {
              "translation": {
                "language": "en",
                "text": "starting Monday"
              }
            }
          ],
          "url": [
            {
              "translation": {
                "language": "en",
                "text": "http://www.mbta.com/about_the_mbta/news_events/?id=6442456143&month=&year="
              }
            }
          ]
        }
      ]
    })

    assert Parse.Alerts.parse(body) == [
             %Alert{
               id: "122425",
               active_period: [
                 {Timex.to_datetime({{2016, 5, 23}, {4, 30, 0}}, "America/New_York"), nil}
               ],
               banner: "Banner Text!",
               cause: "UNKNOWN_CAUSE",
               created_at: Timex.to_datetime({{2016, 4, 14}, {14, 3, 16}}, "America/New_York"),
               description: "description",
               effect: "SCHEDULE_CHANGE",
               header:
                 "New Commuter Rail schedules become effective today, Monday, May 23rd. To view updated schedules, go to mbta.com.",
               informed_entity: [
                 %{route_type: 2, route: "CR-Fairmount"},
                 %{route: "5", stop: "10032", trip: "trip", direction_id: 1}
               ],
               lifecycle: "NEW",
               service_effect: "Commuter Rail schedule change",
               severity: 3,
               short_header:
                 "New Commuter Rail schedules become effective today, Monday, May 23rd. To view updated schedules, go to mbta.com.",
               timeframe: "starting Monday",
               updated_at: Timex.to_datetime({{2016, 5, 23}, {5, 27, 6}}, "America/New_York"),
               url: "http://www.mbta.com/about_the_mbta/news_events/?id=6442456143&month=&year="
             }
           ]
  end

  test "can parse elevator alerts" do
    body = ~s({
      "alerts": [
        {
          "active_period": [
            {
              "start": 1439307059
            }
          ],
          "alert_lifecycle": "ONGOING",
          "cause": "MAINTENANCE",
          "cause_name": "maintenance",
          "created_timestamp": 1439307067,
          "effect": "OTHER_EFFECT",
          "effect_detail": "ACCESS_ISSUE",
          "header_text": [
            {
              "translation": {
                "language": "en",
                "text": "Escalator 417 COURTHOUSE - Outbound to Lobby South unavailable due to maintenance"
              }
            }
          ],
          "id": "89517",
          "informed_entity": [
            {
              "facility_id": "417",
              "stop_id": "74612"
            },
            {
              "facility_id": "417",
              "stop_id": "74616"
            }
          ],
          "last_modified_timestamp": 1439307067,
          "service_effect_text": [
            {
              "translation": {
                "language": "en",
                "text": "escalator unavailable"
              }
            }
          ],
          "severity": 3,
          "short_header_text": [
            {
              "translation": {
                "language": "en",
                "text": "Escalator 417 COURTHOUSE - Outbound to Lobby South unavailable due to maintenance"
              }
            }
          ],
          "timeframe_text": [
            {
              "translation": {
                "language": "en",
                "text": "ongoing"
              }
            }
          ]
        }
      ]
    })

    assert Parse.Alerts.parse(body) == [
             %Alert{
               id: "89517",
               effect: "ACCESS_ISSUE",
               cause: "MAINTENANCE",
               service_effect: "escalator unavailable",
               url: nil,
               header:
                 "Escalator 417 COURTHOUSE - Outbound to Lobby South unavailable due to maintenance",
               short_header:
                 "Escalator 417 COURTHOUSE - Outbound to Lobby South unavailable due to maintenance",
               description: nil,
               severity: 3,
               created_at: Timex.to_datetime(~N[2015-08-11T11:31:07], "America/New_York"),
               updated_at: Timex.to_datetime(~N[2015-08-11T11:31:07], "America/New_York"),
               timeframe: "ongoing",
               lifecycle: "ONGOING",
               active_period: [
                 {Timex.to_datetime(~N[2015-08-11T11:30:59], "America/New_York"), nil}
               ],
               informed_entity: [
                 %{stop: "74612", facility: "417"},
                 %{stop: "74616", facility: "417"}
               ]
             }
           ]
  end

  describe "parse_json/1" do
    test "can parse a basic JSON map" do
      map = %{
        "timestamp" => "1496832813",
        "alerts" => [
          %{
            "active_period" => [
              %{
                "start" => 1_496_305_800,
                "end" => 1_496_989_800
              }
            ],
            "alert_lifecycle" => "NEW",
            "cause" => "CONSTRUCTION",
            "cause_detail" => "CONSTRUCTION",
            "created_timestamp" => 1_494_947_991,
            "description_text" => [
              %{"translation" => %{"language" => "en", "text" => "description"}}
            ],
            "duration_certainty" => "KNOWN",
            "effect" => "NO_SERVICE",
            "effect_detail" => "STATION_CLOSURE",
            "header_text" => [%{"translation" => %{"language" => "en", "text" => "Salem closed"}}],
            "id" => "113791",
            "informed_entity" => [
              %{
                "agency_id" => "1",
                "route_id" => "CR-Newburyport",
                "stop_id" => "Salem",
                "route_type" => 2,
                "trip" => %{
                  "trip_id" => "trip ID",
                  "route_id" => "CR-Newburyport",
                  "direction_id" => 1
                },
                "facility_id" => "facility ID"
              }
            ],
            "last_modified_timestamp" => 1_494_947_991,
            "last_push_notification_timestamp" => 1_494_947_991,
            "service_effect_text" => [
              %{"translation" => %{"language" => "en", "text" => "Salem closed"}}
            ],
            "severity" => 7,
            "short_header_text" => [
              %{
                "translation" => %{
                  "language" => "en",
                  "text" => "Salem closed from Thu Jun 1 through Thu Jun 8 due to construction"
                }
              }
            ],
            "timeframe_text" => [
              %{"translation" => %{"language" => "en", "text" => "through tomorrow"}}
            ],
            "url" => [%{"translation" => %{"language" => "en", "text" => "http://www.mbta.com/"}}]
          }
        ]
      }

      assert parse_json(map) == [
               %Alert{
                 id: "113791",
                 effect: "STATION_CLOSURE",
                 cause: "CONSTRUCTION",
                 header: "Salem closed",
                 short_header:
                   "Salem closed from Thu Jun 1 through Thu Jun 8 due to construction",
                 description: "description",
                 severity: 7,
                 created_at: iso_date("2017-05-16T11:19:51-04:00"),
                 updated_at: iso_date("2017-05-16T11:19:51-04:00"),
                 active_period: [
                   {iso_date("2017-06-01T04:30:00-04:00"), iso_date("2017-06-09T02:30:00-04:00")}
                 ],
                 informed_entity: [
                   %{
                     stop: "Salem",
                     route: "CR-Newburyport",
                     route_type: 2,
                     direction_id: 1,
                     trip: "trip ID",
                     facility: "facility ID"
                   }
                 ],
                 service_effect: "Salem closed",
                 timeframe: "through tomorrow",
                 lifecycle: "NEW",
                 url: "http://www.mbta.com/"
               }
             ]
    end

    test "handles unknown causes" do
      map = %{
        "timestamp" => "1496832813",
        "alerts" => [
          %{
            "active_period" => [],
            "alert_lifecycle" => "NEW",
            "cause" => "UNKNOWN_CAUSE",
            "created_timestamp" => 1_494_947_991,
            "description_text" => [],
            "duration_certainty" => "KNOWN",
            "effect" => "NO_SERVICE",
            "effect_detail" => "STATION_CLOSURE",
            "header_text" => [],
            "id" => "113791",
            "informed_entity" => [%{}],
            "last_modified_timestamp" => 1_494_947_991,
            "last_push_notification_timestamp" => 1_494_947_991,
            "service_effect_text" => [],
            "severity" => 3,
            "short_header_text" => [],
            "timeframe_text" => []
          }
        ]
      }

      assert [%Alert{cause: "UNKNOWN_CAUSE"}] = parse_json(map)
    end

    test "ignores text in a different language" do
      map = %{
        "timestamp" => "1496832813",
        "alerts" => [
          %{
            "active_period" => [],
            "alert_lifecycle" => "NEW",
            "cause" => "UNKNOWN_CAUSE",
            "created_timestamp" => 1_494_947_991,
            "description_text" => [
              %{"translation" => %{"language" => "es", "text" => "Buenos días"}},
              %{"translation" => %{"language" => "en", "text" => "Good morning"}}
            ],
            "duration_certainty" => "KNOWN",
            "effect" => "NO_SERVICE",
            "effect_detail" => "STATION_CLOSURE",
            "header_text" => [],
            "id" => "113791",
            "informed_entity" => [%{}],
            "last_modified_timestamp" => 1_494_947_991,
            "last_push_notification_timestamp" => 1_494_947_991,
            "service_effect_text" => [],
            "severity" => 3,
            "short_header_text" => [],
            "timeframe_text" => []
          }
        ]
      }

      assert [%Alert{description: "Good morning"}] = parse_json(map)
    end

    test "parses a description with an object translation" do
      map = %{
        "timestamp" => "1496832813",
        "alerts" => [
          %{
            "active_period" => [],
            "alert_lifecycle" => "NEW",
            "cause" => "UNKNOWN_CAUSE",
            "created_timestamp" => 1_494_947_991,
            "description_text" => %{
              "translation" => [%{"language" => "en", "text" => "Good morning"}]
            },
            "duration_certainty" => "KNOWN",
            "effect" => "NO_SERVICE",
            "effect_detail" => "STATION_CLOSURE",
            "header_text" => [],
            "id" => "113791",
            "informed_entity" => [%{}],
            "last_modified_timestamp" => 1_494_947_991,
            "last_push_notification_timestamp" => 1_494_947_991,
            "service_effect_text" => [],
            "severity" => 3,
            "short_header_text" => [],
            "timeframe_text" => []
          }
        ]
      }

      assert [%Alert{description: "Good morning"}] = parse_json(map)
    end

    test "does not require all fields in informed entity" do
      map = %{
        "timestamp" => "1496832813",
        "alerts" => [
          %{
            "active_period" => [],
            "alert_lifecycle" => "NEW",
            "cause" => "UNKNOWN_CAUSE",
            "created_timestamp" => 1_494_947_991,
            "description_text" => [],
            "duration_certainty" => "KNOWN",
            "effect" => "NO_SERVICE",
            "effect_detail" => "STATION_CLOSURE",
            "header_text" => [],
            "id" => "113791",
            "informed_entity" => [
              %{"route_id" => "CR-Lowell", "direction_id" => 1}
            ],
            "last_modified_timestamp" => 1_494_947_991,
            "last_push_notification_timestamp" => 1_494_947_991,
            "service_effect_text" => [],
            "severity" => 3,
            "short_header_text" => [],
            "timeframe_text" => []
          }
        ]
      }

      assert [alert] = parse_json(map)
      assert alert.informed_entity == [%{route: "CR-Lowell", direction_id: 1}]
    end

    test "can parse banner text" do
      map = %{
        "timestamp" => "1496832813",
        "alerts" => [
          %{
            "active_period" => [],
            "alert_lifecycle" => "NEW",
            "cause" => "UNKNOWN_CAUSE",
            "created_timestamp" => 1_494_947_991,
            "description_text" => [],
            "banner_text" => [
              %{"translation" => %{"language" => "es", "text" => "Buenos días"}},
              %{"translation" => %{"language" => "en", "text" => "Good morning"}}
            ],
            "duration_certainty" => "KNOWN",
            "effect" => "NO_SERVICE",
            "effect_detail" => "STATION_CLOSURE",
            "header_text" => [],
            "id" => "113791",
            "informed_entity" => [%{}],
            "last_modified_timestamp" => 1_494_947_991,
            "last_push_notification_timestamp" => 1_494_947_991,
            "service_effect_text" => [],
            "severity" => 3,
            "short_header_text" => [],
            "timeframe_text" => []
          }
        ]
      }

      assert [%Alert{banner: "Good morning"}] = parse_json(map)
    end

    test "empty descriptions are nil" do
      map = %{
        "timestamp" => "1496832813",
        "alerts" => [
          %{
            "active_period" => [],
            "alert_lifecycle" => "NEW",
            "cause" => "UNKNOWN_CAUSE",
            "created_timestamp" => 1_494_947_991,
            "description_text" => [%{"translation" => %{"language" => "en", "text" => ""}}],
            "banner_text" => [],
            "duration_certainty" => "KNOWN",
            "effect" => "NO_SERVICE",
            "effect_detail" => "STATION_CLOSURE",
            "header_text" => [],
            "id" => "113791",
            "informed_entity" => [%{}],
            "last_modified_timestamp" => 1_494_947_991,
            "last_push_notification_timestamp" => 1_494_947_991,
            "service_effect_text" => [],
            "severity" => 3,
            "short_header_text" => [],
            "timeframe_text" => []
          }
        ]
      }

      assert [%Alert{description: nil}] = parse_json(map)
    end

    test "descriptions have the header removed from the beginning" do
      map = %{
        "timestamp" => "1496832813",
        "alerts" => [
          %{
            "active_period" => [],
            "alert_lifecycle" => "NEW",
            "cause" => "UNKNOWN_CAUSE",
            "created_timestamp" => 1_494_947_991,
            "description_text" => [
              %{
                "translation" => %{"language" => "en", "text" => "Salem closed. more description"}
              }
            ],
            "banner_text" => [],
            "duration_certainty" => "KNOWN",
            "effect" => "NO_SERVICE",
            "effect_detail" => "STATION_CLOSURE",
            "header_text" => [%{"translation" => %{"language" => "en", "text" => "Salem closed"}}],
            "id" => "113791",
            "informed_entity" => [%{}],
            "last_modified_timestamp" => 1_494_947_991,
            "last_push_notification_timestamp" => 1_494_947_991,
            "service_effect_text" => [],
            "severity" => 3,
            "short_header_text" => [],
            "timeframe_text" => []
          }
        ]
      }

      assert [%Alert{description: "more description"}] = parse_json(map)
    end

    test "closed alerts aren't parsed" do
      data = %{
        "alerts" => [
          %{
            "closed_timestamp" => 0
          }
        ]
      }

      assert [] = parse_json(data)
    end

    test "alerts without informed entities don't parse" do
      data = %{
        "alerts" => [
          %{
            "active_period" => [],
            "alert_lifecycle" => "NEW",
            "cause" => "UNKNOWN_CAUSE",
            "created_timestamp" => 1_494_947_991,
            "description_text" => [],
            "banner_text" => [],
            "duration_certainty" => "KNOWN",
            "effect" => "NO_SERVICE",
            "effect_detail" => "STATION_CLOSURE",
            "header_text" => [%{"translation" => %{"language" => "en", "text" => "Salem closed"}}],
            "id" => "113791",
            "last_modified_timestamp" => 1_494_947_991,
            "last_push_notification_timestamp" => 1_494_947_991,
            "service_effect_text" => [],
            "severity" => 3,
            "short_header_text" => [],
            "timeframe_text" => []
          }
        ]
      }

      # don't crash: it can either return an alert or not
      assert parse_json(data) == []
    end

    test "alerts can be parsed from the 'entity' top-level key" do
      map = %{
        "timestamp" => "1496832813",
        "entity" => [
          %{
            "id" => "113791",
            "alert" => %{
              "active_period" => [],
              "alert_lifecycle" => "NEW",
              "cause" => "UNKNOWN_CAUSE",
              "created_timestamp" => 1_494_947_991,
              "description_text" => [
                %{
                  "translation" => %{
                    "language" => "en",
                    "text" => "Salem closed. more description"
                  }
                }
              ],
              "banner_text" => [],
              "duration_certainty" => "KNOWN",
              "effect" => "NO_SERVICE",
              "effect_detail" => "STATION_CLOSURE",
              "header_text" => [
                %{"translation" => %{"language" => "en", "text" => "Salem closed"}}
              ],
              "informed_entity" => [%{}],
              "last_modified_timestamp" => 1_494_947_991,
              "last_push_notification_timestamp" => 1_494_947_991,
              "service_effect_text" => [],
              "severity" => 3,
              "short_header_text" => [],
              "timeframe_text" => []
            }
          }
        ]
      }

      refute parse_json(map) == []
    end

    test "activities are optional" do
      map = %{
        "alerts" => [
          %{
            "id" => "1",
            "active_period" => [],
            "cause" => "UNKNOWN_CAUSE",
            "created_timestamp" => 1_494_947_991,
            "effect_detail" => "STATION_CLOSURE",
            "informed_entity" => [
              %{"route_type" => 2}
            ],
            "last_modified_timestamp" => 1_494_947_991
          }
        ]
      }

      assert [%Model.Alert{informed_entity: informed_entities}] = parse_json(map)
      assert is_list(informed_entities)
      assert length(informed_entities) == 1

      [informed_entity] = informed_entities

      refute Map.has_key?(informed_entity, "activities")
    end

    test "activities can be a [activity]" do
      map = %{
        "alerts" => [
          %{
            "id" => "1",
            "active_period" => [],
            "cause" => "UNKNOWN_CAUSE",
            "created_timestamp" => 1_494_947_991,
            "effect_detail" => "STATION_CLOSURE",
            "informed_entity" => [
              %{
                "activities" => [
                  "BOARD",
                  "EXIT"
                ]
              }
            ],
            "last_modified_timestamp" => 1_494_947_991
          }
        ]
      }

      assert [%Model.Alert{informed_entity: informed_entities}] = parse_json(map)
      assert is_list(informed_entities)
      assert length(informed_entities) == 1
      assert [%{activities: activities}] = informed_entities
      assert is_list(activities)
      assert length(activities) == 2
      assert "BOARD" in activities
      assert "EXIT" in activities
    end
  end

  describe "lifecycle/1" do
    test "consolidates UPCOMING-ONGOING versions into ONGOING_UPCOMING" do
      assert lifecycle("UPCOMING-ONGOING") == "ONGOING_UPCOMING"
      assert lifecycle("UPCOMING ONGOING") == "ONGOING_UPCOMING"
      assert lifecycle("ONGOING UPCOMING") == "ONGOING_UPCOMING"
      assert lifecycle("ONGOING_UPCOMING") == "ONGOING_UPCOMING"
    end

    test "handles the other normal cases" do
      assert lifecycle("NEW") == "NEW"
      assert lifecycle("UPCOMING") == "UPCOMING"
      assert lifecycle("ONGOING") == "ONGOING"
    end

    test "other values are UNKNOWN" do
      assert lifecycle("whatever") == "UNKNOWN"
    end
  end

  defp iso_date(iso_date_string) do
    # make sure the DateTime is in the America/New_York timezone, not just
    # GMT-4
    iso_date_string
    |> Timex.parse!("{ISO:Extended}")
    |> Timex.to_datetime("America/New_York")
  end
end
