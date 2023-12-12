defmodule State.Trip.AddedTest do
  @moduledoc false
  use ExUnit.Case
  import State.Trip.Added
  @trip_id "added_trip"
  @route_id "route"
  @route_pattern_id "pattern"
  @route_type 3
  @direction_id 0
  @prediction %Model.Prediction{
    trip_id: @trip_id,
    route_id: @route_id,
    route_pattern_id: @route_pattern_id,
    direction_id: @direction_id,
    schedule_relationship: :added
  }

  setup_all do
    stops = [
      %Model.Stop{id: "other", name: "Other"},
      %Model.Stop{id: "child", parent_station: "parent", name: "Child"},
      %Model.Stop{id: "parent", name: "Parent"},
      %Model.Stop{id: "shape", name: "Last Stop on Shape"}
    ]

    route = %Model.Route{
      id: @route_id,
      type: @route_type
    }

    State.Stop.new_state(stops)
    State.Route.new_state([route])

    on_exit(fn ->
      State.Stop.new_state([])
      State.Route.new_state([])
    end)

    :ok
  end

  setup do
    new_state([])
    :ok
  end

  defp insert_predictions(predictions) do
    State.Prediction.new_state(predictions)
    # wait for update
    last_updated()
    :ok
  end

  describe "init/1" do
    test "subscribes to State.Prediction" do
      assert {:ok, _state, _} = init(nil)
      State.Prediction.new_state([])
      assert_receive {:event, {:new_state, State.Prediction}, _, _}
    end
  end

  describe "handle_event/4" do
    test "builds a trip based on the route and last stop" do
      predictions = [
        %{@prediction | stop_id: "child"}
      ]

      insert_predictions(predictions)

      assert [
               %Model.Trip{
                 id: @trip_id,
                 route_id: @route_id,
                 route_pattern_id: @route_pattern_id,
                 route_type: @route_type,
                 headsign: "Parent",
                 wheelchair_accessible: 1,
                 name: ""
               }
             ] = by_id(@trip_id)
    end

    test "uses the prediction with the largest stop sequence" do
      predictions = [
        %{@prediction | stop_sequence: 3, stop_id: "child"},
        %{@prediction | stop_sequence: 2, stop_id: "other"}
      ]

      insert_predictions(predictions)
      assert [%{headsign: "Parent"}] = by_id(@trip_id)
    end

    test "can use the name of a regular stop" do
      predictions = [
        %{@prediction | stop_sequence: 1},
        %{@prediction | stop_sequence: 2, stop_id: "other"}
      ]

      insert_predictions(predictions)
      assert [%{headsign: "Other"}] = by_id(@trip_id)
    end

    test "doesn't create a trip if we can't find a name based on the stop" do
      predictions = [
        %{@prediction | stop_id: "unknown"}
      ]

      insert_predictions(predictions)
      assert by_id(@trip_id) == []
    end

    test "creates a trip even if the schedule relationship is nil" do
      predictions = [
        %{@prediction | schedule_relationship: nil, stop_id: "child"}
      ]

      insert_predictions(predictions)

      assert [
               %Model.Trip{}
             ] = by_id(@trip_id)
    end

    test "creates a trip with revenue value set to :REVENUE" do
      predictions = [
        %{@prediction | revenue: :REVENUE, stop_id: "child"}
      ]

      insert_predictions(predictions)

      assert [
               %Model.Trip{
                 revenue: :REVENUE
               }
             ] = by_id(@trip_id)
    end

    test "creates a trip with revenue value set to :NON_REVENUE" do
      predictions = [
        %{@prediction | revenue: :NON_REVENUE, stop_id: "child"}
      ]

      insert_predictions(predictions)

      assert [
               %Model.Trip{
                 revenue: :NON_REVENUE
               }
             ] = by_id(@trip_id)
    end
  end

  describe "handle_event/4 with shapes" do
    setup do
      trip_id = "scheduled_trip"
      shape_id = "shape_id"

      State.Shape.new_state([
        shape = %Model.Shape{id: shape_id, direction_id: 0, route_id: @route_id, priority: 1}
      ])

      State.Trip.new_state([
        %Model.Trip{id: trip_id, route_id: @route_id, direction_id: 0, shape_id: shape_id}
      ])

      State.Schedule.new_state([
        %Model.Schedule{trip_id: trip_id, stop_sequence: 1, stop_id: "child"},
        %Model.Schedule{trip_id: trip_id, stop_sequence: 2, stop_id: "shape"}
      ])

      State.StopsOnRoute.update!()

      on_exit(fn ->
        State.Shape.new_state([])
        State.Trip.new_state([])
        State.Schedule.new_state([])
        State.StopsOnRoute.update!()
      end)

      prediction = %{@prediction | stop_id: "child"}
      {:ok, %{shape: shape, prediction: prediction}}
    end

    test "if there's a matching shape for the route/direction, uses the last stop from that shape",
         %{prediction: prediction} do
      insert_predictions([prediction])
      assert [%{headsign: "Last Stop on Shape"}] = by_id(@trip_id)
    end

    test "does not use a shape on the wrong route or direction", %{
      shape: shape,
      prediction: prediction
    } do
      State.Shape.new_state([%{shape | route_id: "other route"}])
      State.Trip.new_state([])
      insert_predictions([prediction])
      assert [%{headsign: "Parent"}] = by_id(@trip_id)

      State.Shape.new_state([%{shape | direction_id: 1}])
      insert_predictions([prediction])
      assert [%{headsign: "Parent"}] = by_id(@trip_id)
    end

    test "does not use a shape which doesn't include the last predicted stop", %{
      prediction: prediction
    } do
      State.Schedule.new_state([
        %Model.Schedule{trip_id: "scheduled_trip", stop_sequence: 2, stop_id: "shape"}
      ])

      State.StopsOnRoute.update!()
      insert_predictions([prediction])
      assert [%{headsign: "Parent"}] = by_id(@trip_id)
    end

    test "does not use a shape which has a negative priority", %{
      shape: shape,
      prediction: prediction
    } do
      State.Shape.new_state([%{shape | priority: -1}])
      insert_predictions([prediction])
      assert [%{headsign: "Parent"}] = by_id(@trip_id)
    end

    test "doesn't create a trip when the stop doesn't match any shape" do
      predictions = [%{@prediction | stop_id: "unknown"}]
      insert_predictions(predictions)
      assert by_id(@trip_id) == []
    end

    test "creates a trip with revenue value set to :REVENUE",
         %{prediction: prediction} do
      insert_predictions([%{prediction | revenue: :REVENUE}])
      assert [%{headsign: "Last Stop on Shape", revenue: :REVENUE}] = by_id(@trip_id)
    end

    test "creates a trip with revenue value set to false",
         %{prediction: prediction} do
      insert_predictions([%{prediction | revenue: :NON_REVENUE}])
      assert [%{headsign: "Last Stop on Shape", revenue: :NON_REVENUE}] = by_id(@trip_id)
    end
  end

  describe "handle_event/4 with route patterns" do
    setup do
      trip_id = "scheduled_trip"

      State.RoutePattern.new_state([
        %Model.RoutePattern{id: @route_pattern_id, representative_trip_id: trip_id}
      ])

      State.Trip.new_state([
        %Model.Trip{id: trip_id, route_id: @route_id, direction_id: 0, headsign: "Headsign"}
      ])

      State.Schedule.new_state([
        %Model.Schedule{trip_id: trip_id, stop_sequence: 1, stop_id: "child"},
        %Model.Schedule{trip_id: trip_id, stop_sequence: 2, stop_id: "shape"}
      ])

      State.StopsOnRoute.update!()

      on_exit(fn ->
        State.RoutePattern.new_state([])
        State.Trip.new_state([])
        State.Schedule.new_state([])
      end)
    end

    test "if there's a matching route_pattern, use the representative trip" do
      insert_predictions([%{@prediction | stop_id: "child"}])
      assert [%{headsign: "Headsign"}] = by_id(@trip_id)
    end

    test "creates a trip with revenue value set to :REVENUE" do
      insert_predictions([%{@prediction | stop_id: "child", revenue: :REVENUE}])
      assert [%{headsign: "Headsign", revenue: :REVENUE}] = by_id(@trip_id)
    end

    test "creates a trip with revenue value set to :NON_REVENUE" do
      insert_predictions([%{@prediction | stop_id: "child", revenue: :NON_REVENUE}])
      assert [%{headsign: "Headsign", revenue: :NON_REVENUE}] = by_id(@trip_id)
    end
  end
end
