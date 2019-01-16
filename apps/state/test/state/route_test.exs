defmodule State.RouteTest do
  use ExUnit.Case

  @directions_blob """
  route_id,direction_id,direction,direction_destination
  Mattapan,0,Outbound,Mattapan
  Mattapan,1,Inbound,Ashmont
  Orange,0,South,Forest Hills
  Orange,1,North,Oak Grove
  """

  @routes_blob """
  route_id,agency_id,route_short_name,route_long_name,route_desc,route_fare_class,route_type,route_url,route_color,route_text_color,route_sort_order,line_id,listed_route
  Mattapan,1,,Mattapan Trolley,Rapid Transit,Rapid Transit,0,,DA291C,FFFFFF,2,line-Mattapan,
  Orange,1,,Orange Line,Rapid Transit,Rapid Transit,1,,ED8B00,FFFFFF,3,line-Orange,1
  Green-B,1,B,Green Line B,Rapid Transit,Rapid Transit,0,,00843D,FFFFFF,4,line-Green,
  """

  setup do
    State.Route.new_state([])
    :ok
  end

  test "returns nil for unknown routes" do
    assert State.Route.by_id("1") == nil
    assert State.Route.all() == []
  end

  test "it can add a route and query it" do
    route = %Model.Route{id: "1", short_name: "1"}
    State.Route.new_state([route])

    assert State.Route.by_id("1") == route
    assert State.Route.all() == [route]
  end

  test "all can sort items by their sort order" do
    last = %Model.Route{id: "last", sort_order: 100}
    first = %Model.Route{id: "first", sort_order: 1}
    State.Route.new_state([last, first])

    assert State.Route.all(order_by: {:sort_order, :asc}) == [first, last]
  end

  test "by_ids returns routes in sorted order" do
    last = %Model.Route{id: "last", sort_order: 100}
    first = %Model.Route{id: "first", sort_order: 1}
    State.Route.new_state([last, first])

    assert State.Route.by_ids(["last", "first"]) == [first, last]
  end

  test "by_type returns routes in sorted order" do
    last = %Model.Route{id: "last", sort_order: 100}
    first = %Model.Route{id: "first", sort_order: 1}
    State.Route.new_state([last, first])

    assert State.Route.by_type(nil) == [first, last]
  end

  test "by_type only returns routes with the given type" do
    one = %Model.Route{id: "one", type: 1}
    State.Route.new_state([one])

    assert State.Route.by_type(1) == [one]
    assert State.Route.by_type(3) == []
  end

  test "can parse a binary state" do
    state =
      "\"route_id\",\"agency_id\",\"route_short_name\",\"route_long_name\",\"route_desc\",\"route_fare_class\",\"route_type\",\"route_url\",\"route_color\",\"route_text_color\",\"route_sort_order\",\"line_id\",\"listed_route\"\r\n\"CapeFlyer\",\"3\",\"\",\"CapeFLYER\",\"\",\"Rapid Transit\",2,\"http://capeflyer.com/\",\"006595\",\"FFFFFF\",100,\"\",\"\",\r\n\"Logan-22\",\"2\",\"Shuttle\",\"Massport Subway Shuttle (22)\",\"Airport Shuttle\",\"Outer Express\",3,\"\",\"\",\"\",2000022,\"\",\"\"\r\n"

    State.Route.new_state(state)

    refute State.Route.by_id("CapeFlyer") == nil
  end

  describe "direction names and desitnations parsing" do
    test "returns correct directions map" do
      direction_map = State.Route.get_direction_map(@directions_blob)

      assert direction_map == %{
               {"Mattapan", "0"} => [
                 %Parse.Directions{
                   direction: "Outbound",
                   direction_destination: "Mattapan",
                   direction_id: "0",
                   route_id: "Mattapan"
                 }
               ],
               {"Mattapan", "1"} => [
                 %Parse.Directions{
                   direction: "Inbound",
                   direction_destination: "Ashmont",
                   direction_id: "1",
                   route_id: "Mattapan"
                 }
               ],
               {"Orange", "0"} => [
                 %Parse.Directions{
                   direction: "South",
                   direction_destination: "Forest Hills",
                   direction_id: "0",
                   route_id: "Orange"
                 }
               ],
               {"Orange", "1"} => [
                 %Parse.Directions{
                   direction: "North",
                   direction_destination: "Oak Grove",
                   direction_id: "1",
                   route_id: "Orange"
                 }
               ]
             }
    end

    test "gets correct value for routes" do
      direction_map = State.Route.get_direction_map(@directions_blob)
      routes = State.Route.get_routes(@routes_blob, direction_map)

      assert routes == [
               %Model.Route{
                 color: "DA291C",
                 description: "Rapid Transit",
                 fare_class: "Rapid Transit",
                 listed_route: true,
                 agency_id: "1",
                 line_id: "line-Mattapan",
                 direction_destinations: ["Mattapan", "Ashmont"],
                 direction_names: ["Outbound", "Inbound"],
                 id: "Mattapan",
                 long_name: "Mattapan Trolley",
                 short_name: "",
                 sort_order: 2,
                 text_color: "FFFFFF",
                 type: 0
               },
               %Model.Route{
                 color: "ED8B00",
                 description: "Rapid Transit",
                 fare_class: "Rapid Transit",
                 listed_route: false,
                 agency_id: "1",
                 line_id: "line-Orange",
                 direction_destinations: ["Forest Hills", "Oak Grove"],
                 direction_names: ["South", "North"],
                 id: "Orange",
                 long_name: "Orange Line",
                 short_name: "",
                 sort_order: 3,
                 text_color: "FFFFFF",
                 type: 1
               },
               %Model.Route{
                 color: "00843D",
                 description: "Rapid Transit",
                 fare_class: "Rapid Transit",
                 listed_route: true,
                 agency_id: "1",
                 line_id: "line-Green",
                 direction_destinations: [nil, nil],
                 direction_names: [nil, nil],
                 id: "Green-B",
                 long_name: "Green Line B",
                 short_name: "B",
                 sort_order: 4,
                 text_color: "FFFFFF",
                 type: 0
               }
             ]
    end

    test "correctly processed by handle_event" do
      {:ok, init_state} = State.Route.init([])
      event = {:fetch, "directions.txt"}

      assert {:noreply, state, :hibernate} =
               State.Route.handle_event(event, @directions_blob, nil, init_state)

      assert %{
               data: %Events.Gather{
                 callback: _,
                 keys: [fetch: "directions.txt", fetch: "routes.txt"],
                 received: %{
                   {:fetch, "directions.txt"} => @directions_blob
                 }
               },
               last_updated: nil
             } = state

      event = {:fetch, "routes.txt"}

      assert {:noreply, state, :hibernate} =
               State.Route.handle_event(event, @routes_blob, nil, state)

      assert %{
               data: %Events.Gather{
                 callback: _,
                 keys: [fetch: "directions.txt", fetch: "routes.txt"],
                 received: %{
                   {:fetch, "directions.txt"} => @directions_blob,
                   {:fetch, "routes.txt"} => @routes_blob
                 }
               },
               last_updated: nil
             } = state
    end

    test "gathers fetch events for both files" do
      assert :ok ==
               State.Route.do_gather(%{
                 {:fetch, "directions.txt"} => @directions_blob,
                 {:fetch, "routes.txt"} => @routes_blob
               })
    end
  end
end
