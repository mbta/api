defmodule Parse.TripUpdatesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Parse.GtfsRt.TripUpdates

  # 2017-08-09 10:46:40 EDT
  @arrival_time 1_502_290_000
  # 2017-08-09 10:55:00 EDT
  @departure_time 1_502_290_500

  describe "parse/1" do
    test "parses complete trip update with all fields" do
      body =
        Jason.encode!(%{
          entity: [
            %{
              trip_update: %{
                trip: %{
                  "trip_id" => "trip-1",
                  "route_id" => "route-1",
                  "route_pattern_id" => "pattern-1",
                  "direction_id" => 0,
                  "schedule_relationship" => "SCHEDULED",
                  "revenue" => true,
                  "last_trip" => true
                },
                vehicle: %{"id" => "vehicle-1"},
                update_type: "mid_trip",
                stop_time_update: [
                  %{
                    "stop_id" => "stop-1",
                    "stop_sequence" => 1,
                    "arrival" => %{"time" => @arrival_time, "uncertainty" => 60},
                    "departure" => %{"time" => @departure_time, "uncertainty" => 120},
                    "schedule_relationship" => "SCHEDULED",
                    "boarding_status" => "Boarding"
                  }
                ]
              }
            }
          ]
        })

      [prediction] = parse(body)

      assert %Model.Prediction{
               trip_id: "trip-1",
               route_id: "route-1",
               route_pattern_id: "pattern-1",
               direction_id: 0,
               vehicle_id: "vehicle-1",
               revenue: :REVENUE,
               last_trip?: true,
               update_type: :mid_trip,
               stop_id: "stop-1",
               stop_sequence: 1,
               arrival_uncertainty: 60,
               departure_uncertainty: 120,
               status: "Boarding"
             } = prediction
    end

    test "parses multiple entities with multiple stops each" do
      body =
        Jason.encode!(%{
          entity: [
            %{
              trip_update: %{
                trip: %{"trip_id" => "trip-1", "route_id" => "route-1", "direction_id" => 0},
                stop_time_update: [
                  %{"stop_id" => "stop-1", "stop_sequence" => 1},
                  %{"stop_id" => "stop-2", "stop_sequence" => 2}
                ]
              }
            },
            %{
              trip_update: %{
                trip: %{"trip_id" => "trip-2", "route_id" => "route-2", "direction_id" => 1},
                stop_time_update: [
                  %{"stop_id" => "stop-3", "stop_sequence" => 1}
                ]
              }
            }
          ]
        })

      assert [
               %{trip_id: "trip-1", stop_id: "stop-1"},
               %{trip_id: "trip-1", stop_id: "stop-2"},
               %{trip_id: "trip-2", stop_id: "stop-3"}
             ] = parse(body)
    end

    test "parses schedule_relationship values" do
      for {input, expected} <- [
            {"ADDED", :added},
            {"CANCELED", :cancelled},
            {"UNSCHEDULED", :unscheduled},
            {"SKIPPED", :skipped},
            {"NO_DATA", :no_data},
            {"SCHEDULED", nil}
          ] do
        body =
          Jason.encode!(%{
            entity: [
              %{
                trip_update: %{
                  trip: %{
                    "trip_id" => "trip-1",
                    "schedule_relationship" => input
                  },
                  stop_time_update: [%{"stop_id" => "stop-1"}]
                }
              }
            ]
          })

        [prediction] = parse(body)
        assert prediction.schedule_relationship == expected
      end
    end

    test "parses revenue values" do
      for {input, expected} <- [{true, :REVENUE}, {false, :NON_REVENUE}] do
        body =
          Jason.encode!(%{
            entity: [
              %{
                trip_update: %{
                  trip: %{"trip_id" => "trip-1", "revenue" => input},
                  stop_time_update: [%{"stop_id" => "stop-1"}]
                }
              }
            ]
          })

        [prediction] = parse(body)
        assert prediction.revenue == expected
      end
    end

    test "applies default values for missing fields" do
      body =
        Jason.encode!(%{
          entity: [
            %{
              trip_update: %{
                trip: %{"trip_id" => "trip-1"},
                stop_time_update: [%{"stop_id" => "stop-1"}]
              }
            }
          ]
        })

      assert [%{revenue: :REVENUE, last_trip?: false}] = parse(body)
    end

    test "parses update_type values" do
      for {input, expected} <- [
            {"mid_trip", :mid_trip},
            {"at_terminal", :at_terminal},
            {"reverse_trip", :reverse_trip}
          ] do
        body =
          Jason.encode!(%{
            entity: [
              %{
                trip_update: %{
                  trip: %{"trip_id" => "trip-1"},
                  update_type: input,
                  stop_time_update: [%{"stop_id" => "stop-1"}]
                }
              }
            ]
          })

        [prediction] = parse(body)
        assert prediction.update_type == expected
      end
    end

    test "handles stop-level schedule_relationship overriding trip-level" do
      body =
        Jason.encode!(%{
          entity: [
            %{
              trip_update: %{
                trip: %{"trip_id" => "trip-1", "schedule_relationship" => "ADDED"},
                stop_time_update: [
                  %{"stop_id" => "stop-1", "schedule_relationship" => "SKIPPED"}
                ]
              }
            }
          ]
        })

      [prediction] = parse(body)
      assert prediction.schedule_relationship == :skipped
    end

    test "preserves CANCELLED from trip level when stop has different relationship" do
      body =
        Jason.encode!(%{
          entity: [
            %{
              trip_update: %{
                trip: %{"trip_id" => "trip-1", "schedule_relationship" => "CANCELED"},
                stop_time_update: [
                  %{"stop_id" => "stop-1", "schedule_relationship" => "SKIPPED"}
                ]
              }
            }
          ]
        })

      [prediction] = parse(body)
      assert prediction.schedule_relationship == :cancelled
    end

    test "ignores entities without trip_update" do
      body = Jason.encode!(%{entity: [%{}, %{"other" => "data"}]})
      assert parse(body) == []
    end

    test "ignores trips without stop_time_updates" do
      body =
        Jason.encode!(%{
          entity: [
            %{
              trip_update: %{
                trip: %{"trip_id" => "trip-1"}
              }
            }
          ]
        })

      assert parse(body) == []
    end

    test "handles missing optional fields" do
      body =
        Jason.encode!(%{
          entity: [
            %{
              trip_update: %{
                trip: %{"trip_id" => "trip-1"},
                stop_time_update: [%{"stop_id" => "stop-1"}]
              }
            }
          ]
        })

      assert [
               %{
                 route_pattern_id: nil,
                 vehicle_id: nil,
                 update_type: nil,
                 arrival_time: nil,
                 departure_time: nil,
                 status: nil
               }
             ] = parse(body)
    end
  end
end
