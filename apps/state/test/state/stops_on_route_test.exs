defmodule State.StopsOnRouteTest do
  use ExUnit.Case
  use Timex

  import State.StopsOnRoute

  @route %Model.Route{id: "route"}
  @service %Model.Service{
    id: "service",
    start_date: Timex.today(),
    end_date: Timex.today(),
    added_dates: [Timex.today()]
  }
  @trip %Model.Trip{
    id: "trip",
    route_id: "route",
    shape_id: "pattern",
    direction_id: 1,
    service_id: "service",
    route_pattern_id: "route_pattern_id"
  }
  @other_trip %Model.Trip{
    id: "other_trip",
    route_id: "route",
    shape_id: "other_pattern",
    direction_id: 0,
    service_id: "other_service",
    route_pattern_id: "other_route_pattern_id"
  }
  @schedule %Model.Schedule{trip_id: "trip", stop_id: "stop", stop_sequence: 2}
  @other_schedule %Model.Schedule{trip_id: "other_trip", stop_id: "other_stop", stop_sequence: 1}

  setup do
    State.Stop.new_state([%Model.Stop{id: "stop"}, %Model.Stop{id: "other_stop"}])

    State.RoutePattern.new_state([
      %Model.RoutePattern{id: "route_pattern_id", typicality: 1},
      %Model.RoutePattern{id: "other_route_pattern_id", typicality: 2}
    ])

    State.Route.new_state([@route])
    State.Trip.new_state([@trip, @other_trip])
    State.Service.new_state([@service])
    State.Schedule.new_state([@schedule, @other_schedule])
    State.Shape.new_state([])
    update!()
  end

  describe "by_route_id/2" do
    test "returns the stop IDs on a given route" do
      assert by_route_id("route", direction_id: 1) == ["stop"]
      assert by_route_id("route", direction_id: 0) == ["other_stop"]
      assert by_route_id("route", service_ids: ["service"]) == ["stop"]

      assert Enum.sort(by_route_id("route", service_ids: ["service", "other_service"])) == [
               "other_stop",
               "stop"
             ]

      assert by_route_id(
               "route",
               direction_id: 1,
               service_ids: ["service", "other_service"]
             ) == ["stop"]

      assert by_route_id("route", shape_ids: ["pattern"]) == ["stop"]
      assert Enum.sort(by_route_id("route")) == ["other_stop", "stop"]
      assert by_route_id("unknown") == []
    end

    test "returns stop IDs in sequence order" do
      other_schedule = %Model.Schedule{trip_id: "trip", stop_id: "other_stop", stop_sequence: 1}
      State.Schedule.new_state([@schedule, other_schedule])
      update!()
      assert by_route_id("route") == ["other_stop", "stop"]
    end

    test "does not include alternate route trips unless asked" do
      adjusted_trip = %Model.Trip{@other_trip | alternate_route: false}
      alternate_trip = %Model.Trip{@trip | id: "alternate_trip", alternate_route: true}

      alternate_schedule = %Model.Schedule{
        @schedule
        | trip_id: "alternate_trip",
          stop_id: "alternate_stop"
      }

      State.Stop.new_state([%Model.Stop{id: "alternate_stop"} | State.Stop.all()])
      State.Trip.new_state([@trip, adjusted_trip, alternate_trip])
      State.Schedule.new_state([@schedule, @other_schedule, alternate_schedule])
      update!()

      assert by_route_id("route") == ["stop"]

      assert Enum.sort(by_route_id("route", include_alternates?: true)) == [
               "alternate_stop",
               "other_stop",
               "stop"
             ]

      # if we don't have regular service, try alternate service
      assert by_route_id("route", service_ids: ["other_service"]) == ["other_stop"]
    end

    test "does not include a parent station more than once" do
      State.Stop.new_state([
        %Model.Stop{id: "stop", parent_station: "parent"},
        %Model.Stop{id: "other_stop", parent_station: "parent"}
      ])

      update!()

      assert by_route_id("route") == ["parent"]
    end

    test "keeps stops in a global order even if a single shape does not determine the order" do
      # Stops go outbound 0 -> 3, and inbound 3 -> 0
      # the "short" shapes go to either Stop 2 or Stop 3, but not both
      stops =
        for id <- 0..3 do
          %Model.Stop{id: "stop-#{id}"}
        end

      trips =
        for {trip_id, shape_id} <- [all: "all", first: "short", second: "short"] do
          %Model.Trip{
            id: "#{trip_id}",
            direction_id: 0,
            shape_id: "#{shape_id}",
            route_id: @route.id
          }
        end ++
          [
            # Inbound trip
            %Model.Trip{id: "reverse", direction_id: 1, shape_id: "other", route_id: @route.id}
          ]

      schedules =
        for {{trip_id, id}, stop_sequence} <-
              Enum.with_index([
                {"all", 0},
                {"all", 1},
                {"all", 2},
                {"all", 3},
                {"first", 0},
                {"first", 1},
                {"first", 3},
                {"second", 0},
                {"second", 2},
                {"second", 3},
                {"reverse", 3},
                {"reverse", 2},
                {"reverse", 1},
                {"reverse", 0}
              ]) do
          %Model.Schedule{
            stop_id: "stop-#{id}",
            trip_id: "#{trip_id}",
            stop_sequence: stop_sequence
          }
        end

      State.Stop.new_state(stops)
      State.Trip.new_state(trips)
      State.Schedule.new_state(schedules)
      update!()

      assert by_route_id(@route.id, shape_ids: ["short"]) == [
               "stop-0",
               "stop-1",
               "stop-2",
               "stop-3"
             ]
    end

    test "global order is not confused by shuttles" do
      # Stops go outbound 0 -> 3
      # the shuttle shape goes from 3 to 0
      stops =
        for id <- 0..3 do
          %Model.Stop{id: "stop-#{id}"}
        end

      trips =
        for {trip_id, shape_id, route_type} <- [
              {"all", "all", nil},
              {"express", "all", nil},
              {"shuttle", "shuttle", 4}
            ] do
          %Model.Trip{
            id: trip_id,
            direction_id: 0,
            shape_id: shape_id,
            route_type: route_type,
            route_id: @route.id
          }
        end

      # we need the "express" trip to have a different set of shapes from the
      # "all" trip
      schedules =
        for {{trip_id, id}, stop_sequence} <-
              Enum.with_index([
                {"all", 0},
                {"all", 1},
                {"all", 2},
                {"all", 3},
                {"express", 0},
                {"express", 3},
                {"shuttle", 3},
                {"shuttle", 2},
                {"shuttle", 1},
                {"shuttle", 0}
              ]) do
          %Model.Schedule{
            stop_id: "stop-#{id}",
            trip_id: "#{trip_id}",
            stop_sequence: stop_sequence
          }
        end

      State.Stop.new_state(stops)
      State.Trip.new_state(trips)
      State.Schedule.new_state(schedules)
      update!()

      assert by_route_id(@route.id, direction_id: 0) == ["stop-0", "stop-1", "stop-2", "stop-3"]
    end

    test "if a shape has all the same stops not in the global order, keep the shape order" do
      # Stops go outbound 0 -> 3, and inbound 3 -> 0
      # the "short" shapes go to either Stop 2 or Stop 3, but not both
      stops =
        for id <- 0..2 do
          %Model.Stop{id: "stop-#{id}"}
        end

      trips =
        for {trip_id, shape_id} <- [first: "first", second: "second"] do
          %Model.Trip{
            id: "#{trip_id}",
            direction_id: 0,
            shape_id: "#{shape_id}",
            route_id: @route.id
          }
        end

      schedules =
        for {{trip_id, id}, stop_sequence} <-
              Enum.with_index([
                {"first", 0},
                {"first", 1},
                {"first", 2},
                {"second", 0},
                {"second", 2},
                {"second", 1}
              ]) do
          %Model.Schedule{
            stop_id: "stop-#{id}",
            trip_id: "#{trip_id}",
            stop_sequence: stop_sequence
          }
        end

      State.Stop.new_state(stops)
      State.Trip.new_state(trips)
      State.Schedule.new_state(schedules)
      update!()

      first_ids = by_route_id(@route.id, shape_ids: ["first"])
      second_ids = by_route_id(@route.id, shape_ids: ["second"])

      refute first_ids == second_ids
    end

    test "if trip doesn't have a route pattern, it's not included" do
      # "stop" is on this shape, "other_stop" is on a different shape
      trip = %{@trip | route_type: 2}
      State.Trip.new_state([trip, @other_trip])
      update!()
      assert by_route_id(@route.id) == ["other_stop"]
    end

    test "shows Plimptonville after Windsor Gardens even when they don't share a trip" do
      State.Stop.new_state([
        %Model.Stop{id: "place-sstat"},
        %Model.Stop{id: "Windsor Gardens"},
        %Model.Stop{id: "Plimptonville"},
        %Model.Stop{id: "Walpole"},
        %Model.Stop{id: "Franklin"}
      ])

      State.Route.new_state([%Model.Route{id: "CR-Franklin"}])

      State.Trip.new_state([
        %Model.Trip{
          id: "via-plimptonville",
          route_id: "CR-Franklin",
          direction_id: 0,
          service_id: "service"
        },
        %Model.Trip{
          id: "via-windsor-gardens",
          route_id: "CR-Franklin",
          direction_id: 0,
          service_id: "service"
        }
      ])

      State.Schedule.new_state([
        %Model.Schedule{trip_id: "via-plimptonville", stop_id: "place-sstat", stop_sequence: 1},
        %Model.Schedule{trip_id: "via-plimptonville", stop_id: "Plimptonville", stop_sequence: 2},
        %Model.Schedule{trip_id: "via-plimptonville", stop_id: "Franklin", stop_sequence: 3},
        # Windsor Gardens trip has more stops because this bug only shows up when the merge
        # has windor gardens on the left and plimptonville on the right.
        # They're sorted by length before merging, so this forces them to be in the order to make the bug appear.
        %Model.Schedule{trip_id: "via-windsor-gardens", stop_id: "place-sstat", stop_sequence: 1},
        %Model.Schedule{
          trip_id: "via-windsor-gardens",
          stop_id: "Windsor Gardens",
          stop_sequence: 2
        },
        %Model.Schedule{trip_id: "via-windsor-gardens", stop_id: "Walpole", stop_sequence: 3},
        %Model.Schedule{trip_id: "via-windsor-gardens", stop_id: "Franklin", stop_sequence: 4}
      ])

      update!()

      stop_ids = by_route_id("CR-Franklin")

      assert Enum.filter(stop_ids, &(&1 in ["Windsor Gardens", "Plimptonville"])) == [
               "Windsor Gardens",
               "Plimptonville"
             ]
    end

    test "can drop stops from a route" do
      trip_id = "fairmont-trip"
      stop_ids = ["place-sstat", "place-FB-0109", "place-FB-0118"]

      State.Stop.new_state(for stop_id <- stop_ids, do: %Model.Stop{id: stop_id})
      State.Route.new_state([%Model.Route{id: "CR-Fairmount"}])
      State.Trip.new_state([%Model.Trip{id: trip_id, route_id: "CR-Fairmount", direction_id: 1}])

      State.Schedule.new_state(
        for {stop_id, sequence} <- Enum.with_index(stop_ids),
            do: %Model.Schedule{trip_id: trip_id, stop_id: stop_id, stop_sequence: sequence}
      )

      update!()

      stop_ids = by_route_id("CR-Fairmount")

      assert stop_ids == ["place-sstat", "place-FB-0118"]
    end
  end

  describe "by_route_ids/2" do
    test "takes multiple route_ids to match against" do
      State.Stop.new_state([%Model.Stop{id: "new_stop"} | State.Stop.all()])

      State.Route.new_state([
        @route,
        %{@route | id: "new_route"}
      ])

      State.Trip.new_state([
        @trip,
        %{@trip | id: "new_trip", route_id: "new_route"}
      ])

      State.Schedule.new_state([
        @schedule,
        %{@schedule | trip_id: "new_trip", stop_id: "new_stop"}
      ])

      update!()
      assert by_route_ids(["route"]) == by_route_id("route")
      assert [_, _] = by_route_ids(["route", "new_route"])
    end
  end

  describe "merge_ids/1" do
    test "merges the lists, keeping a relative order" do
      assert merge_ids([[1, 2, 4, 5], [2, 3, 4, 5], [3, 5, 6]]) == [1, 2, 3, 4, 5, 6]
      assert merge_ids([]) == []
      assert merge_ids([[], []]) == []
      assert merge_ids([[1], []]) == [1]
      assert merge_ids([[], [1]]) == [1]
    end

    test "handles lists with branches" do
      # based on outbound Providence/Stoughton
      stop_ids = [
        [13, 14, 15],
        [1, 2, 5, 7, 8],
        [1, 2, 5, 9, 10, 11, 12, 13],
        [1, 2, 5, 11],
        [1, 2, 3, 5, 6, 9, 10, 11, 12, 13],
        [1, 2, 5, 6, 7, 8],
        [1, 2, 3, 5, 6, 9, 10, 11, 12, 13, 14, 15],
        [1, 2, 3, 4, 5, 6, 7, 8]
      ]

      # stoughton first, then prov
      expected = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
      assert merge_ids(stop_ids) == expected
    end

    test "puts the longer branch at the end" do
      stop_ids = [
        [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15],
        [3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 15],
        [8, 9, 10, 11, 12, 13, 14, 15]
      ]

      assert merge_ids(stop_ids) == Enum.into(1..15, [])
      assert merge_ids(Enum.map(stop_ids, &Enum.reverse/1)) == Enum.into(15..1, [])
    end

    test "puts the higher valued ID at the end with branches" do
      stop_ids = [
        [1, 2, 3, 4],
        [1, 2, 5, 6]
      ]

      assert merge_ids(stop_ids) == [1, 2, 3, 4, 5, 6]
      assert merge_ids(Enum.map(stop_ids, &Enum.reverse/1)) == [6, 5, 4, 3, 2, 1]
    end

    test "does not include IDs multiple times" do
      stop_ids = [
        [1, 2, 3],
        [1, 3, 2]
      ]

      # There isn't a single defined order (that we can determine) but we
      # know that there are only three items.
      assert [_, _, _] = merge_ids(stop_ids)
    end

    test "can use an override to order individual stops" do
      stop_ids =
        Enum.shuffle([
          [1, 2, 3, 5, 6],
          [1, 2, 4, 5, 6]
        ])

      overrides = [[2, 4, 3, 5]]

      assert [1, 2, 4, 3, 5, 6] == merge_ids(stop_ids, overrides)
    end
  end

  test "doesn't override itself if there are no schedules" do
    assert by_route_id("route", direction_id: 1) == ["stop"]

    State.Schedule.new_state([])
    update!()

    assert by_route_id("route", direction_id: 1) == ["stop"]
  end
end
