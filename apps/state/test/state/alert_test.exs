defmodule State.AlertTest do
  use ExUnit.Case

  alias Parse.Time
  alias State.Alert.{InformedEntity, InformedEntityActivity}

  import State.Alert

  @alert_id "alert"
  @alert_id2 "alert2"
  @route_id "9"
  @service_id "service"
  @trip_id "trip"
  @trip %Model.Trip{
    block_id: "block_id",
    id: @trip_id,
    route_id: @route_id,
    direction_id: 1,
    service_id: @service_id
  }
  @today Time.service_date()

  @alert %Model.Alert{
    id: @alert_id,
    informed_entity: [
      %{
        route_type: 3,
        route: @route_id,
        direction_id: @trip.direction_id,
        trip: @trip_id,
        activities: InformedEntityActivity.default_activities()
      }
    ],
    severity: 1
  }
  @alert2 %Model.Alert{
    id: @alert_id2,
    informed_entity: [
      %{
        route_type: 3,
        route: @route_id,
        direction_id: @trip.direction_id,
        trip: @trip_id,
        activities: InformedEntityActivity.default_activities()
      }
    ],
    severity: 2
  }

  setup do
    State.Alert.new_state([])
    State.Route.new_state([])
    State.Stop.new_state([])
    State.Schedule.new_state([])
    State.Trip.new_state([])
    :ok
  end

  defp insert_alerts!(alerts) do
    State.Alert.new_state(alerts)
    :ok
  end

  describe "init/1" do
    setup do
      Application.stop(:state)

      on_exit(fn ->
        Application.start(:state)
      end)
    end

    test "subscribes to State.Trip" do
      assert {:ok, _state, _} = init(nil)
      {:ok, _} = State.Trip.start_link()
      assert_receive {:event, {:new_state, State.Trip}, _, _}
    end

    test "creates InformedEntity and InformedEntityActivity tables" do
      assert :ets.info(InformedEntity)
      assert :ets.info(InformedEntityActivity)
    end
  end

  describe "filter_by/1" do
    test "empty filter == all alerts (with the default activities)" do
      insert_alerts!([@alert])
      assert filter_by(%{}) == all()
    end

    test "can filter by a list of severities" do
      insert_alerts!([@alert, @alert2])
      assert filter_by(%{severity: [1]}) == [@alert]
      assert filter_by(%{severity: [2]}) == [@alert2]
      assert filter_by(%{severity: [1, 2, 3]}) == all()
      assert filter_by(%{severity: [3]}) == []
      assert filter_by(%{severity: nil}) == all()
    end

    test "can filter by a list of activities" do
      limited_mobility_alert = %{
        @alert
        | id: "mobility",
          informed_entity: [%{activities: ["USING_ESCALATOR"]}]
      }

      insert_alerts!([@alert, limited_mobility_alert])
      assert [%{id: @alert_id}] = filter_by(%{activities: ["BOARD"]})
      # should use default activities
      assert [%{id: @alert_id}] = filter_by(%{activities: []})
      # should also use default activities
      assert [%{id: @alert_id}] = filter_by(%{})
      assert [_, _] = filter_by(%{activities: ["BOARD", "USING_ESCALATOR"]})
      assert [_, _] = filter_by(%{activities: ["ALL"]})
      assert [] = filter_by(%{activities: ["USING_WHEELCHAIR"]})
    end

    test "can filter by facility" do
      facility_alert = %{
        @alert
        | id: "facility",
          informed_entity: [%{activities: ["BOARD"], facility: "facility"}]
      }

      insert_alerts!([facility_alert])
      assert [%{id: "facility"}] = filter_by(%{facilities: ["facility"]})
      assert [%{id: "facility"}] = filter_by(%{facilities: ["facility", "other facility"]})
      assert [] = filter_by(%{facilities: [nil]})
      assert [] = filter_by(%{facilities: ["other facility"]})
    end

    test "can filter by multiple parts of an informed_entity" do
      entities = [
        # MUST be subset of `State.Alert.InformedEntityActivity.default_activities/0`
        %{activities: ["BOARD", "EXIT"], stop: "1", route: "2", route_type: 3, direction_id: 0}
      ]

      alert = put_in(@alert.informed_entity, entities)
      insert_alerts!([alert])

      assert [_] = filter_by(%{stops: ["1"], routes: ["2"]})
      assert [_] = filter_by(%{stops: ["1", "2"], routes: ["2", "3"]})
      assert [] = filter_by(%{stops: ["1"], routes: ["not route"]})
      assert [] = filter_by(%{stops: ["not stop"], routes: ["2"]})
      assert [] = filter_by(%{stops: ["2"], facilities: []})
      assert [_] = filter_by(%{routes: ["2"], direction_id: 0})
      assert [] = filter_by(%{routes: ["2"], direction_id: 1})
      assert [] = filter_by(%{routes: ["2"], route_types: [2]})
      assert [_] = filter_by(%{routes: ["2"], route_types: [3]})
      assert [_] = filter_by(%{facilities: [nil]})
      assert [] = filter_by(%{facilities: ["fac"]})
      assert [] = filter_by(%{facilities: ["fac1", "fac2"]})
      assert [_] = filter_by(%{activities: ["BOARD"], stops: ["1"]})
      assert [_] = filter_by(%{activities: ["ALL"], stops: ["1"]})
    end

    test "filtering by route/type/direction_id returns alerts that apply to a trip on the route" do
      route = %Model.Route{
        type: 1,
        id: "Red"
      }

      State.Route.new_state([route])

      trip = %Model.Trip{
        id: "trip",
        route_id: "Red",
        direction_id: 1
      }

      State.Trip.new_state([trip])

      alert =
        put_in(@alert.informed_entity, [
          %{
            activities: ["BOARD"],
            trip: trip,
            route: route.id,
            route_type: route.type,
            direction_id: 1
          }
        ])

      insert_alerts!([alert])

      assert [_] = filter_by(%{routes: ["Red"]})
      assert [_] = filter_by(%{routes: ["Red"], direction_id: 1})
      assert [] = filter_by(%{routes: ["Red"], direction_id: 0})
      assert [] = filter_by(%{routes: ["Blue"], direction_id: 1})
      assert [_] = filter_by(%{route_types: [1]})
    end

    test "filtering by trip returns alerts that apply to the route or type" do
      route = %Model.Route{
        type: 1,
        id: "Red"
      }

      State.Route.new_state([route])

      trip = %Model.Trip{
        id: "trip",
        route_id: "Red",
        direction_id: 1
      }

      State.Trip.new_state([trip])

      entities = [
        %{activities: ["BOARD"], route_type: 1, route: "Red", direction_id: 1},
        %{activities: ["BOARD"], route_type: 1, route: "Red"},
        %{activities: ["BOARD"], route_type: 1, direction_id: 1},
        %{activities: ["BOARD"], route_type: 1}
      ]

      alerts =
        for {entity, index} <- Enum.with_index(entities) do
          Map.merge(@alert, %{id: "alert-#{index}", informed_entity: [entity]})
        end

      # make sure we don't match alerts going the other way
      other_direction_alert =
        put_in(@alert.informed_entity, [
          %{activities: ["BOARD"], route_type: 1, route: "Red", direction_id: 0}
        ])

      insert_alerts!([other_direction_alert | alerts])

      assert length(filter_by(%{trips: ["trip"]})) == length(alerts)
      assert filter_by(%{trips: ["other_trip"]}) == []
    end

    test "filtering by route returns alerts that apply to the route type" do
      route = %Model.Route{
        type: 1,
        id: "Red"
      }

      State.Route.new_state([route])

      entities = [
        %{activities: ["BOARD"], route_type: 1, direction_id: 1},
        %{activities: ["BOARD"], route_type: 1}
      ]

      alerts =
        for {entity, index} <- Enum.with_index(entities) do
          Map.merge(@alert, %{id: "alert-#{index}", informed_entity: [entity]})
        end

      insert_alerts!(alerts)

      assert length(filter_by(%{routes: ["Red"]})) == length(alerts)
    end

    test "filtering by stop returns alerts which impact that route" do
      route = %Model.Route{
        type: 1,
        id: "Red"
      }

      State.Route.new_state([route])

      stop = %Model.Stop{
        id: "stop"
      }

      State.Stop.new_state([stop])

      trip = %Model.Trip{
        id: "trip",
        route_id: route.id,
        direction_id: 1
      }

      State.Trip.new_state([trip])

      schedule = %Model.Schedule{
        trip_id: trip.id,
        stop_id: stop.id,
        route_id: route.id
      }

      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      entity = %{activities: ["BOARD"], route: route.id}
      alert = %{@alert | informed_entity: [entity]}
      insert_alerts!([alert])

      assert [_] = filter_by(%{stops: [stop.id]})
    end

    test "filtering by stop does not return alerts which impact other stops on that route" do
      route = %Model.Route{
        type: 1,
        id: "Red"
      }

      State.Route.new_state([route])

      stop = %Model.Stop{
        id: "stop"
      }

      State.Stop.new_state([stop])

      trip = %Model.Trip{
        id: "trip",
        route_id: route.id,
        direction_id: 1
      }

      State.Trip.new_state([trip])

      schedule = %Model.Schedule{
        trip_id: trip.id,
        stop_id: stop.id
      }

      State.Schedule.new_state([schedule])
      State.RoutesPatternsAtStop.update!()
      entity = %{activities: ["BOARD"], route: route.id, stop: "other stop"}
      alert = %{@alert | informed_entity: [entity]}
      insert_alerts!([alert])

      assert [] = filter_by(%{stops: [stop.id]})
    end

    test "filtering by multiple IDs" do
      informed_entity = [%{activities: InformedEntityActivity.default_activities()}]

      alerts = [
        alert1 = %Model.Alert{id: "1", informed_entity: informed_entity},
        alert2 = %Model.Alert{id: "2", informed_entity: informed_entity},
        _alert3 = %Model.Alert{id: "3", informed_entity: informed_entity}
      ]

      insert_alerts!(alerts)

      assert [^alert1, ^alert2] = Enum.sort_by(filter_by(%{ids: ["1", "2"]}), & &1.id)
    end

    test "filtering by banner returns alerts with/without banner" do
      entity = %{activities: ["BOARD"]}

      alerts =
        for i <- 1..2 do
          %Model.Alert{
            id: "alert-#{i}",
            banner: (&if(&1 == 1, do: "banner #{i}", else: nil)).(i),
            informed_entity: [entity]
          }
        end

      insert_alerts!(alerts)

      assert [%{id: "alert-1"}] = filter_by(%{activities: ["BOARD"], banner: true})
      assert [%{id: "alert-1"}] = filter_by(%{banner: true})
      assert [%{id: "alert-2"}] = filter_by(%{activities: ["BOARD"], banner: false})
      assert [%{id: "alert-2"}] = filter_by(%{banner: false})
    end

    test "can filter by datetime" do
      alert = %{
        @alert
        | active_period: [
            {DateTime.from_unix!(1000), DateTime.from_unix!(2000)}
          ]
      }

      insert_alerts!([alert])
      assert filter_by(%{datetime: DateTime.from_unix!(1500)}) == [alert]
      assert filter_by(%{datetime: DateTime.from_unix!(2000)}) == []
    end

    test "can filter by lifecycle" do
      alert = %{@alert | lifecycle: "ONGOING"}
      insert_alerts!([alert])
      assert filter_by(%{lifecycles: ["ONGOING", "UPCOMING"]}) == [alert]
      assert filter_by(%{lifecycles: ["UPCOMING"]}) == []
    end
  end

  describe "events" do
    test "has a consistent state when the :new_state event is published" do
      # Note: This guards against a bug that occurred inconsistently due to a race condition. If
      # the bug is not present, it should never fail. If the bug is present, it will fail most of
      # the time, but not necessarily every time.
      test_pid = self()

      spawn_link(fn ->
        Events.subscribe({:new_state, State.Alert})
        send(test_pid, :ready)

        receive do
          {:event, {:new_state, State.Alert}, 1, _} ->
            assert filter_by(%{routes: [@route_id]}) == [@alert]
        after
          100 -> flunk("never received new_state event")
        end

        send(test_pid, :done)
      end)

      assert_receive :ready
      insert_alerts!([@alert])
      assert_receive :done, 200
    end
  end
end
