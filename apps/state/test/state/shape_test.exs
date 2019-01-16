defmodule State.ShapeTest do
  use ExUnit.Case
  alias Model.{Route, Schedule, Shape, Stop, Trip}
  alias Parse.{Polyline, Variant}
  import State.Shape

  test "init" do
    assert {:ok, %{data: _, last_updated: nil}} = State.Shape.init([])
  end

  describe "new_state/1" do
    setup _ do
      State.StopsOnRoute.empty!()
    end

    test "assigns patterns based on shape/variant data" do
      polylines = [
        %Polyline{id: "shape"},
        %Polyline{id: "not_a_variant"},
        %Polyline{id: "no_matching_trip"}
      ]

      variants = [
        %Variant{
          id: "shape",
          name: "variant",
          primary?: true
        }
      ]

      trips = [
        %Trip{
          id: "1",
          route_id: "1",
          headsign: "headsign",
          shape_id: "shape"
        },
        %Trip{
          id: "2",
          route_id: "2",
          headsign: "headsign 2",
          shape_id: "not_a_variant"
        }
      ]

      State.Trip.new_state(trips)
      State.Shape.new_state({polylines, variants})

      assert by_id("shape") == [
               %Model.Shape{
                 id: "shape",
                 route_id: "1",
                 name: "variant",
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

    test "prefers a non-replaced route ID when making shapes primary" do
      polylines = [
        %Polyline{id: "1920018"},
        %Polyline{id: "390068"}
      ]

      variants = [
        %Variant{
          id: "1920018",
          name: "Haymarket",
          primary?: true,
          replaced?: true
        },
        %Variant{
          id: "390068",
          name: "Back Bay",
          primary?: true,
          replaced?: false
        }
      ]

      trips = [
        %Trip{
          id: "1",
          shape_id: "1920018"
        },
        %Trip{
          id: "2",
          shape_id: "390068"
        }
      ]

      State.Trip.new_state(trips)
      State.Shape.new_state({polylines, variants})
      assert [_, _] = State.Shape.all()
      poly1 = "390068" |> by_id() |> List.first()
      poly2 = "1920018" |> by_id() |> List.first()
      assert poly1.priority > poly2.priority
    end

    test "only keeps one shape if they have the same stops (including parent stations)" do
      polylines = [
        %Polyline{id: "one"},
        %Polyline{id: "one_with_same_parent"},
        %Polyline{id: "two"}
      ]

      variants = []

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

      State.Shape.new_state({polylines, variants})
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

      variants = []

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

      State.Shape.new_state({polylines, variants})
      shapes = State.Shape.select_routes([nil], nil)
      assert Enum.map(shapes, &{&1.id, &1.priority}) == [{"two", 2}, {"one", 1}]
    end

    test "prefers shapes with longer polylines" do
      polylines = [
        %Polyline{id: "one", polyline: "123456"},
        %Polyline{id: "two", polyline: "1234567"}
      ]

      variants = []

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

      State.Shape.new_state({polylines, variants})
      shapes = State.Shape.select_routes([nil], nil)
      assert Enum.map(shapes, &{&1.id, &1.priority}) == [{"two", 2}, {"one", 1}]
    end

    test "keeps both shapes if they have shared, but not the same, stops" do
      polylines = [
        %Polyline{id: "one"},
        %Polyline{id: "two"}
      ]

      variants = []

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

      State.Shape.new_state({polylines, variants})
      shapes = State.Shape.select_routes([nil], nil)
      assert Enum.map(shapes, &{&1.id, &1.priority}) == [{"one", 2}, {"two", 1}]
    end

    test "only keeps shape for primary routes" do
      polylines = [%Polyline{id: "one"}]
      variants = []

      trips = [
        %Trip{
          id: "1",
          shape_id: "one",
          route_id: "route 1",
          alternate_route: false
        },
        %Trip{
          id: "2",
          shape_id: "one",
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
      State.Shape.new_state({polylines, variants})

      assert [
               %{id: "one", route_id: "route 1"},
               %{id: "one", route_id: "route 2"}
             ] = State.Shape.select_routes(["route 1", "route 2", "route 3"], nil)

      assert [%{id: "one"}] = State.Shape.select_routes(["route 1"], nil)
      assert [%{id: "one"}] = State.Shape.select_routes(["route 2"], nil)
    end

    test "keeps the trip with the more common headsign" do
      polylines = [%Polyline{id: "one"}]
      variants = []

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
      State.Shape.new_state({polylines, variants})

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
      assert %{name: "Wickford Junction", priority: 0} = providence
      assert %{name: nil, priority: -1} = shuttle
    end
  end

  describe "select_routes/1" do
    @shapes [
      %Shape{route_id: "1", direction_id: 0, priority: 0},
      %Shape{route_id: "2", direction_id: 0, priority: 0},
      %Shape{route_id: "3", direction_id: 1, priority: 0}
    ]

    setup _ do
      State.Shape.new_state(@shapes)
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

      State.Shape.new_state(shapes)
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
