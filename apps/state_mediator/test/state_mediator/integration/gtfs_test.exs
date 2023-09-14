defmodule StateMediator.Integration.GtfsTest do
  use ExUnit.Case

  @moduledoc """
  Don't run these tests along with the main ones.  Instead, run them alone:

  `$ mix test --include integration --exclude test`

  You can also give them a direct path to a .ZIP file for local testing:

  `$ env MBTA_GTFS_FILE=<path to GTFS.zip> mix test --include integration --exclude test`
  """
  @moduletag :integration

  setup_all do
    Logger.configure(level: :info)
    maybe_start_bypass!(System.get_env("MBTA_GTFS_FILE"))
    :ok = Events.subscribe({:new_state, State.Shape})
    :ok = Events.subscribe({:new_state, State.RoutesPatternsAtStop})
    :ok = Events.subscribe({:new_state, State.StopsOnRoute})
    old_start = Application.get_env(:state_mediator, :start)
    Application.put_env(:state_mediator, :start, true)
    Application.stop(:state_mediator)
    Application.ensure_all_started(:state_mediator)

    on_exit(fn ->
      Application.put_env(:state_mediator, :start, old_start)
      Application.stop(:state_mediator)
    end)

    receive_items(State.RoutesPatternsAtStop)
    receive_items(State.Shape)
    receive_items(State.StopsOnRoute)
    Logger.configure(level: :warn)
  end

  defp maybe_start_bypass!(nil) do
    :ok
  end

  defp maybe_start_bypass!(filename) do
    # if a filename was provided, run a fake webserver to provide it
    filename = Path.expand(filename, Application.get_env(:state_mediator, :cwd))
    bypass = Bypass.open()

    Bypass.expect(bypass, fn conn ->
      Plug.Conn.send_file(conn, 200, filename)
    end)

    realtime_config = Application.get_env(:state_mediator, Realtime)
    realtime_config = put_in(realtime_config[:gtfs_url], "http://127.0.0.1:#{bypass.port}")
    Application.put_env(:state_mediator, Realtime, realtime_config)
  end

  describe "stops" do
    test "correctly calculates first/last stops on routes" do
      assert_first_last_stop_id("Red", "place-alfcl", "place-brntn")
      assert_first_last_stop_id("CR-Providence", "place-sstat", "place-NEC-1659")
      assert_first_last_stop_id("CR-Fairmount", "place-sstat", ["place-DB-0095", "place-FS-0049"])
      assert_first_last_stop_id("CR-Franklin", "place-sstat", "place-FB-0303")
      assert_first_last_stop_id("CR-Haverhill", "place-north", "place-WR-0329")
      assert_first_last_stop_id("CR-Lowell", "place-north", "place-NHRML-0254")
      assert_first_last_stop_id("CR-Kingston", "place-sstat", "place-KB-0351")
      assert_first_last_stop_id("Green-B", "place-gover", "place-lake")
      assert_first_last_stop_id("Green-C", "place-gover", "place-clmnl")
      assert_first_last_stop_id("Green-D", "place-unsqu", "place-river")
      assert_first_last_stop_id("Green-E", ["place-lech", "place-mdftf"], "place-hsmnl")
    end

    test "keeps green line core in the correct order" do
      # prefixes and suffixes are for the extended core, which hit some but
      # not all of the 4 lines
      order_prefixes = %{
        "Green-B" => ~w(place-gover),
        "Green-C" => ~w(place-gover),
        "Green-D" => ~w(place-north place-haecl place-gover),
        "Green-E" => ~w(place-north place-haecl place-gover)
      }

      order = ~w(place-pktrm place-boyls place-armnl place-coecl)

      order_suffixes = %{
        "Green-B" => ~w(place-hymnl place-kencl),
        "Green-C" => ~w(place-hymnl place-kencl),
        "Green-D" => ~w(place-hymnl place-kencl),
        "Green-E" => []
      }

      for route_id <- ~w(Green-B Green-C Green-D Green-E),
          route_order = order_prefixes[route_id] ++ order ++ order_suffixes[route_id],
          date <- dates_of_rating(),
          direction_id <- [0, 1] do
        route_order =
          if direction_id == 1 do
            Enum.reverse(route_order)
          else
            route_order
          end

        core_stop_ids =
          for stop <-
                State.Stop.filter_by(%{routes: [route_id], direction_id: direction_id, date: date}),
              stop.id in route_order,
              do: stop.id

        # only check the order of stop IDs that are on the route. this works
        # around the Haymarket closure
        route_order = Enum.filter(route_order, &(&1 in core_stop_ids))

        assert {route_id, direction_id, date, route_order} ==
                 {route_id, direction_id, date, core_stop_ids}
      end
    end

    test "only includes place-* stops on rapid transit routes" do
      # makes sure we aren't including random other stops
      routes = State.Route.by_types([0, 1])

      invalid_stops_for_subway = fn stops ->
        stops
        |> Enum.map(& &1.id)
        |> Enum.reject(&String.starts_with?(&1, "place-"))
      end

      invalid_routes =
        for date <- [nil | dates_of_rating()],
            %{id: route_id} <- routes,
            # skip Mattapan for right now
            route_id != "Mattapan",
            direction_id <- [0, 1],
            stops =
              State.Stop.filter_by(%{routes: [route_id], direction_id: direction_id, date: date}),
            invalid_stop_ids = invalid_stops_for_subway.(stops),
            invalid_stop_ids != [] do
          {route_id, date, direction_id, invalid_stop_ids}
        end

      assert invalid_routes == []
    end

    test "Broadway @ Temple (2725) is on the 101" do
      invalid? = fn stops ->
        ids = Enum.map(stops, & &1.id)
        "2725" not in ids
      end

      refute invalid?.(State.Stop.filter_by(%{routes: ["101"], direction_id: 0}))

      invalid_dates =
        for date <- dates_of_rating(),
            data =
              State.Stop.filter_by(%{
                routes: ["101"],
                direction_id: 0,
                date: date
              }),
            data != [],
            invalid?.(data) do
          date
        end

      assert invalid_dates == []
    end
  end

  describe "shapes" do
    test "outbound highest-priority shape ends at the end of the route" do
      for route_id <- ~w(CR-Haverhill CR-Lowell CR-Worcester Blue Green-E) do
        [primary_shape | _] = State.Shape.select_routes([route_id], 0)
        [last_stop | _] = stops(route_id, 1)
        # don't require an exact match
        assert primary_shape.name =~ last_stop.name,
               "primary shape #{primary_shape.id} on route #{route_id} should end at #{last_stop.name}, not #{primary_shape.name}"
      end
    end

    test "route 9 inbound primary shape is Copley Square" do
      # not the school trip to Boston Latin
      primary_shape = ["9"] |> State.Shape.select_routes(1) |> List.first()
      %{name: name} = primary_shape
      assert name =~ "Copley"
    end

    test "CR-Lowell inbound has one rail shape with route_id CR-Lowell" do
      assert [_] =
               ["CR-Lowell"]
               |> State.Shape.select_routes(1)
               |> Enum.filter(&(&1.route_id == "CR-Lowell"))
               |> Enum.reject(&(&1.priority < 0))
    end

    test "Red Line has 2 non-ignored shapes each direction" do
      [shapes_0, shapes_1] = shapes_in_both_directions("Red")
      assert [%{name: "Alewife - Braintree"}, %{name: "Alewife - Ashmont"}] = shapes_0
      assert [%{name: "Braintree - Alewife"}, %{name: "Ashmont - Alewife"}] = shapes_1
    end

    test "Providence/Stoughton has 2 non-ignored shapes each direction" do
      [shapes_0, shapes_1] = shapes_in_both_directions("CR-Providence")

      assert [
               %{name: "South Station - Wickford Junction"},
               %{id: "9890004"},
               %{id: "SouthStationToStoughtonViaFairmount"}
             ] = shapes_0

      assert [%{name: "Wickford Junction - South Station"}, %{id: "9890003"}] = shapes_1
    end

    test "Newburyport/Rockport has 2 non-ignored shapes each direction" do
      [shapes_0, shapes_1] = shapes_in_both_directions("CR-Newburyport")

      assert [%{name: "North Station - Rockport"}, %{name: "North Station - Newburyport"}] =
               shapes_0

      assert [%{name: "Rockport - North Station"}, %{name: "Newburyport - North Station"}] =
               shapes_1
    end

    test "all shuttle shapes have negative priority" do
      invalid_shapes =
        for shape <- State.Shape.all(), String.ends_with?(shape.id, "-S"), shape.priority >= 0 do
          shape
        end

      assert invalid_shapes == []
    end

    test "each route has only one highest priority shape" do
      for %{id: route_id} <- all_routes(),
          direction_id <- [0, 1] do
        shapes =
          [route_id]
          |> State.Shape.select_routes(direction_id)
          |> Enum.filter(&(&1.route_id == route_id))

        case shapes do
          [] ->
            :ok

          [%{priority: priority} | _] when priority < 0 ->
            # highest priority shape is ignored, so don't worry about the others
            :ok

          [shape | rest] ->
            assert Enum.filter(rest, &(&1.priority == shape.priority)) == [],
                   "multiple highest priority shapes on route #{route_id}:#{direction_id}"
        end
      end
    end

    test "each trip has a valid shape" do
      for %{shape_id: shape_id} <- State.Trip.all() do
        assert State.Shape.by_id(shape_id)
      end
    end
  end

  describe "alerts" do
    test "all alerts with trips have route type, route, and direction_id" do
      missing_values = fn entity ->
        for expected <- [:route_type, :route, :direction_id], nil == Map.get(entity, expected) do
          expected
        end
      end

      missing_data =
        for alert <- State.Alert.all(),
            %{trip: trip_id} = entity <- alert.informed_entity,
            missing <- missing_values.(entity) do
          {alert.id, trip_id, missing}
        end

      assert missing_data == []
    end

    test "all alerts with routes have route type" do
      missing_data =
        for alert <- State.Alert.all(),
            %{route: _route_id} = entity <- alert.informed_entity,
            Map.get(entity, :route_type) == nil do
          alert.id
        end

      assert missing_data == []
    end
  end

  describe "predictions" do
    test "have valid route, trip and stop IDs" do
      for %{route_id: route_id} <- all_routes(),
          prediction <-
            State.Prediction.select([
              %{route_id: route_id}
            ]) do
        assert State.Route.by_id(prediction.route_id)
        assert State.Trip.by_primary_id(prediction.trip_id)
        assert State.Stop.by_id(prediction.stop_id)
      end
    end
  end

  describe "vehicles" do
    test "have valid route, trip and stop IDs" do
      for %{route_id: route_id} <- all_routes(),
          vehicle <- State.Vehicle.by_effective_route_id(route_id) do
        assert State.Route.by_id(vehicle.route_id)
        assert State.Trip.by_primary_id(vehicle.trip_id)
        assert State.Stop.by_id(vehicle.stop_id)
      end
    end
  end

  describe "facilities" do
    test "have valid types" do
      for facility <- State.Facility.all() do
        assert facility.type in State.Facility.facility_types()
      end
    end
  end

  defp receive_items(module) do
    clear_inbox!()

    receive do
      {:event, {:new_state, ^module}, items, _} when items > 0 ->
        :ok
    end
  end

  defp clear_inbox! do
    receive do
      _ ->
        clear_inbox!()
    after
      0 ->
        :ok
    end
  end

  defp assert_first_last_stop_id(route_id, first_stop_id, last_stop_id) do
    assert {first_0, last_0} = first_last(stops(route_id, 0))
    assert {first_1, last_1} = first_last(stops(route_id, 1))
    assert first_0.id in List.wrap(first_stop_id)
    assert last_0.id in List.wrap(last_stop_id)
    assert first_1.id in List.wrap(last_stop_id)
    assert last_1.id in List.wrap(first_stop_id)
  end

  defp all_routes do
    State.Route.all(order_by: {:sort_order, :asc})
  end

  defp stops(route_id, direction_id) do
    State.Stop.filter_by(%{routes: [route_id], direction_id: direction_id})
  end

  defp dates_of_rating do
    {:ok, feed} = State.Feed.get()

    for dt <-
          Timex.Interval.new(
            from: Parse.Time.service_date(),
            until: feed.end_date,
            right_open: false
          ) do
      NaiveDateTime.to_date(dt)
    end
  end

  defp first_last([first | rest]) do
    {first, List.last(rest)}
  end

  defp shapes_in_both_directions(route) do
    for direction_id <- 0..1 do
      [route]
      |> State.Shape.select_routes(direction_id)
      |> Enum.filter(&(&1.route_id == route))
      |> Enum.reject(&(&1.priority < 0))
    end
  end
end
