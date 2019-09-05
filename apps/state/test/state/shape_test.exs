defmodule State.ShapeTest do
  use ExUnit.Case
  alias Model.{Route, RoutePattern, Schedule, Shape, Stop, Trip}
  alias Parse.Polyline
  import State.Shape

  test "init" do
    assert {:ok, %{data: _, last_updated: nil}} = State.Shape.init([])
  end

  describe "new_state/1" do
    setup do
      State.StopsOnRoute.empty!()
      State.RoutePattern.new_state([])
    end

    test "assigns values based on route patterns" do
      polylines = [
        %Polyline{id: "shape"},
        %Polyline{id: "not_a_variant"},
        %Polyline{id: "no_matching_trip"}
      ]

      patterns = [
        %RoutePattern{
          id: "pattern",
          name: "origin - variant",
          typicality: 1
        }
      ]

      trips = [
        %Trip{
          id: "1",
          route_id: "1",
          headsign: "headsign",
          shape_id: "shape",
          route_pattern_id: "pattern"
        },
        %Trip{
          id: "2",
          route_id: "2",
          headsign: "headsign 2",
          shape_id: "not_a_variant",
          route_pattern_id: nil
        }
      ]

      State.Trip.new_state(trips)
      State.RoutePattern.new_state(patterns)
      State.Shape.new_state(polylines)

      assert by_id("shape") == [
               %Model.Shape{
                 id: "shape",
                 route_id: "1",
                 name: "origin - variant",
                 priority: 3
               }
             ]

      assert by_id("not_a_variant") == [
               %Model.Shape{
                 id: "not_a_variant",
                 route_id: "2",
                 name: "headsign 2",
                 priority: 2
               }
             ]

      assert Enum.empty?(by_id("no_matching_trip"))
    end

    test "uses full pattern name if a hyphen isn't present" do
      polylines = [
        %Polyline{id: "shape"}
      ]

      patterns = [
        %RoutePattern{
          id: "pattern",
          name: "variant",
          typicality: 1
        }
      ]

      trips = [
        %Trip{
          id: "1",
          route_id: "1",
          headsign: "headsign",
          shape_id: "shape",
          route_pattern_id: "pattern"
        }
      ]

      State.Trip.new_state(trips)
      State.RoutePattern.new_state(patterns)
      State.Shape.new_state(polylines)

      assert by_id("shape") == [
               %Model.Shape{
                 id: "shape",
                 route_id: "1",
                 name: "variant",
                 priority: 3
               }
             ]
    end

    test "shapes on atypical patterns have negative priority" do
      polylines = [
        %Polyline{id: "shape"},
        %Polyline{id: "shuttle_shape"}
      ]

      patterns = [
        %RoutePattern{
          id: "pattern",
          name: "",
          typicality: 1
        },
        %RoutePattern{
          id: "shuttle_pattern",
          name: "shuttle_name",
          typicality: 4
        }
      ]

      trips = [
        %Trip{
          id: "1",
          route_id: "1",
          headsign: "headsign",
          shape_id: "shape",
          route_pattern_id: "pattern"
        },
        %Trip{
          id: "2",
          route_id: "1",
          headsign: "shuttle headsign",
          shape_id: "shuttle_shape",
          route_pattern_id: "shuttle_pattern"
        }
      ]

      State.Trip.new_state(trips)
      State.RoutePattern.new_state(patterns)
      State.Shape.new_state(polylines)

      assert by_id("shuttle_shape") == [
               %Model.Shape{
                 id: "shuttle_shape",
                 route_id: "1",
                 name: "shuttle_name",
                 priority: -1
               }
             ]
    end

    test "only keeps one shape if they have the same stops (including parent stations)" do
      polylines = [
        %Polyline{id: "one"},
        %Polyline{id: "one_with_same_parent"},
        %Polyline{id: "two"}
      ]

      trips = [
        %Trip{
          id: "1",
          shape_id: "one"
        },
        %Trip{
          id: "1a",
          shape_id: "one_with_same_parent"
        },
        %Trip{
          id: "2",
          shape_id: "two"
        }
      ]

      stops = [
        %Stop{id: "parent"},
        %Stop{id: "child", parent_station: "parent"},
        %Stop{id: "other"}
      ]

      schedules = [
        %Schedule{
          trip_id: "1",
          stop_id: "child"
        },
        %Schedule{
          trip_id: "1a",
          stop_id: "parent"
        },
        %Schedule{
          trip_id: "2",
          stop_id: "other"
        }
      ]

      State.Stop.new_state(stops)
      State.Schedule.new_state(schedules)
      State.Trip.new_state(trips)
      State.Route.new_state([%Route{}])
      State.StopsOnRoute.update!()

      State.Shape.new_state(polylines)
      shapes = State.Shape.select_routes([nil], nil)

      assert Enum.map(shapes, &{&1.id, &1.priority}) == [
               {"one", 2},
               {"two", 1},
               {"one_with_same_parent", -1}
             ]
    end

    test "prefers shapes with more stops" do
      polylines = [
        %Polyline{id: "one"},
        %Polyline{id: "two"}
      ]

      trips = [
        %Trip{
          id: "1",
          shape_id: "one"
        },
        %Trip{
          id: "2",
          shape_id: "two"
        }
      ]

      stops = [
        %Stop{id: "stop 1"},
        %Stop{id: "stop 2"},
        %Stop{id: "stop 3"}
      ]

      schedules = [
        %Schedule{
          trip_id: "1",
          stop_id: "stop 1"
        },
        %Schedule{
          trip_id: "2",
          stop_id: "stop 2",
          stop_sequence: 1
        },
        %Schedule{
          trip_id: "2",
          stop_id: "stop 3",
          stop_sequence: 2
        }
      ]

      State.Stop.new_state(stops)
      State.Schedule.new_state(schedules)
      State.Trip.new_state(trips)
      State.Route.new_state([%Route{}])
      State.StopsOnRoute.update!()

      State.Shape.new_state(polylines)
      shapes = State.Shape.select_routes([nil], nil)
      assert Enum.map(shapes, &{&1.id, &1.priority}) == [{"two", 2}, {"one", 1}]
    end

    test "prefers shapes with longer polylines" do
      polylines = [
        %Polyline{id: "one", polyline: "123456"},
        %Polyline{id: "two", polyline: "1234567"}
      ]

      trips = [
        %Trip{
          id: "1",
          shape_id: "one"
        },
        %Trip{
          id: "2",
          shape_id: "two"
        }
      ]

      stops = []
      schedules = []
      State.Stop.new_state(stops)
      State.Schedule.new_state(schedules)
      State.Trip.new_state(trips)
      State.Route.new_state([%Route{}])
      State.StopsOnRoute.update!()

      State.Shape.new_state(polylines)
      shapes = State.Shape.select_routes([nil], nil)
      assert Enum.map(shapes, &{&1.id, &1.priority}) == [{"two", 2}, {"one", 1}]
    end

    test "keeps both shapes if they have shared, but not the same, stops" do
      polylines = [
        %Polyline{id: "one"},
        %Polyline{id: "two"}
      ]

      trips = [
        %Trip{
          id: "1",
          shape_id: "one"
        },
        %Trip{
          id: "2",
          shape_id: "two"
        }
      ]

      stops = [
        %Stop{id: "one"},
        %Stop{id: "two"},
        %Stop{id: "shared"}
      ]

      schedules = [
        %Schedule{
          trip_id: "1",
          stop_id: "one"
        },
        %Schedule{
          trip_id: "1",
          stop_id: "shared"
        },
        %Schedule{
          trip_id: "2",
          stop_id: "two"
        },
        %Schedule{
          trip_id: "2",
          stop_id: "shared"
        }
      ]

      State.Stop.new_state(stops)
      State.Schedule.new_state(schedules)
      State.Trip.new_state(trips)
      State.Route.new_state([%Route{}])
      State.StopsOnRoute.update!()

      State.Shape.new_state(polylines)
      shapes = State.Shape.select_routes([nil], nil)
      assert Enum.map(shapes, &{&1.id, &1.priority}) == [{"one", 2}, {"two", 1}]
    end

    test "only keeps shape for primary routes" do
      polylines = [%Polyline{id: "one"}, %Polyline{id: "two"}, %Polyline{id: "three"}]

      trips = [
        %Trip{
          id: "1",
          shape_id: "one",
          route_id: "route 1",
          alternate_route: false
        },
        %Trip{
          id: "2",
          shape_id: "two",
          route_id: "route 2",
          alternate_route: nil
        },
        %Trip{
          id: "2",
          shape_id: "one",
          route_id: "route 3",
          alternate_route: true
        }
      ]

      State.Trip.new_state(trips)
      State.StopsOnRoute.update!()
      State.Shape.new_state(polylines)

      assert [
               %{id: "one", route_id: "route 1"},
               %{id: "two", route_id: "route 2"}
             ] = State.Shape.select_routes(["route 1", "route 2", "route 3"], nil)

      assert [%{id: "one"}] = State.Shape.select_routes(["route 1"], nil)
      assert [%{id: "two"}] = State.Shape.select_routes(["route 2"], nil)
    end

    test "keeps the trip with the more common headsign" do
      polylines = [%Polyline{id: "one"}]

      trips = [
        %Trip{
          id: "1",
          shape_id: "one",
          route_id: "route",
          headsign: "popular"
        },
        %Trip{
          id: "2",
          shape_id: "one",
          route_id: "route",
          headsign: "popular"
        },
        %Trip{
          id: "3",
          shape_id: "one",
          route_id: "route",
          headsign: "not popular"
        }
      ]

      State.Trip.new_state(trips)
      State.StopsOnRoute.update!()
      State.Shape.new_state(polylines)

      shape = State.Shape.by_primary_id("one")
      assert shape.name == "popular"
    end
  end

  describe "arrange_by_priority/1" do
    test "can override priorities from the configuration" do
      shapes = [
        %Model.Shape{id: "931_0010", priority: 0},
        %Model.Shape{id: "9890008", priority: 0},
        %Model.Shape{id: "FakeShuttle-S", priority: 0}
      ]

      [red_ashmont, providence, shuttle] = State.Shape.arrange_by_priority(shapes)
      assert %{name: "Ashmont", priority: 2} = red_ashmont
      assert %{name: "Wickford Junction - South Station", priority: 0} = providence
      assert %{name: nil, priority: -1} = shuttle
    end
  end

  describe "select_routes/1" do
    @shapes [
      %Shape{id: "1", route_id: "1", direction_id: 0, priority: 0},
      %Shape{id: "2", route_id: "2", direction_id: 0, priority: 0},
      %Shape{id: "3", route_id: "3", direction_id: 1, priority: 0}
    ]

    @trips [
      %Trip{id: "1", route_id: "1", direction_id: 0, shape_id: "1"},
      %Trip{id: "2", route_id: "2", direction_id: 0, shape_id: "2"},
      %Trip{id: "3", route_id: "3", direction_id: 1, shape_id: "3"}
    ]

    setup _ do
      State.Shape.new_state(@shapes)
      State.Trip.new_state(@trips)
      :ok
    end

    test "can return shapes for multiple routes without a direction" do
      assert select_routes(["1", "2"], nil) == Enum.take(@shapes, 2)
      assert select_routes(["2", "3"], nil) == Enum.drop(@shapes, 1)
    end

    test "can return shapes for multiple routes given a direction" do
      assert select_routes(["1", "2", "3"], 0) == Enum.take(@shapes, 2)
      assert select_routes(["1", "2", "3"], 1) == Enum.drop(@shapes, 2)
    end

    test "can return multiple shapes with same id" do
      shapes = [
        %Shape{
          id: "s1",
          route_id: "1",
          direction_id: 1,
          priority: 0
        },
        %Shape{
          id: "s1",
          route_id: "2",
          direction_id: 1,
          priority: 0
        }
      ]

      trips = [
        %Trip{
          id: "t1",
          route_id: "1",
          direction_id: 1,
          shape_id: "s1"
        },
        %Trip{
          id: "t2",
          route_id: "2",
          direction_id: 1,
          shape_id: "s2"
        }
      ]

      State.Shape.new_state(shapes)
      State.Trip.new_state(trips)
      assert select_routes(["1", "2"], 1) == shapes
    end
  end

  describe "by_primary_id/1" do
    test "returns the shape with the highest priority" do
      shapes =
        for priority <- Enum.shuffle(1..4) do
          %Shape{
            id: "s1",
            route_id: "route",
            direction_id: 1,
            priority: priority
          }
        end

      State.Shape.new_state(shapes)

      assert State.Shape.by_primary_id("s1").priority == 4
    end
  end
end
