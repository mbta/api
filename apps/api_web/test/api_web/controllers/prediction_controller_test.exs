defmodule ApiWeb.PredictionControllerTest do
  @moduledoc false
  use ApiWeb.ConnCase
  import ApiWeb.PredictionController

  alias Model.{Prediction, Stop, Trip}

  @route %Model.Route{
    id: "red",
    type: 1,
    sort_order: 1,
    description: "First Route",
    short_name: "First",
    long_name: "The First"
  }

  @stop %Stop{
    id: "1",
    parent_station: "parent"
  }
  @parent_stop %Stop{
    id: "parent"
  }
  {:ok, arrival, _} = DateTime.from_iso8601("2016-11-17 18:00:00-05:00")
  @latest_arrival arrival

  earlier_arrival = fn i ->
    {:ok, time, _} = DateTime.from_iso8601("2016-11-17 15:0#{i}:00-05:00")
    time
  end

  @cr_predictions for i <- 1..5,
                      do: %Prediction{
                        arrival_time: earlier_arrival.(i),
                        stop_id: "#{i}",
                        route_id: "2",
                        stop_sequence: i,
                        trip_id: "trip",
                        vehicle_id: "vehicle",
                        status: "On Time",
                        direction_id: 1
                      }
  @cr_prediction hd(@cr_predictions)

  setup %{conn: conn} do
    State.Trip.new_state([])
    # stop is needed since we look up parent stops
    State.Stop.new_state([@stop, @parent_stop, %Stop{id: "2"}])
    State.Prediction.new_state(@cr_predictions)
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index_data/2" do
    test "returns an error when no filters are specified", %{conn: conn} do
      assert ApiWeb.PredictionController.index_data(conn, %{"sort" => "arrival_time"}) ==
               {:error, :filter_required}
    end

    test "returns an error if only the route_type filter is provided", %{conn: conn} do
      assert ApiWeb.PredictionController.index_data(conn, %{"route_type" => "0,1"}) ==
               {:error, :only_route_type}
    end
  end

  test "predictions can be paginated and are sorted by arrival_time", %{conn: base_conn} do
    conn =
      get(
        base_conn,
        prediction_path(base_conn, :index, %{
          "trip" => "trip",
          "page" => %{"offset" => 0, "limit" => Enum.count(@cr_predictions)}
        })
      )

    assert conn.assigns.data == @cr_predictions

    conn =
      get(
        base_conn,
        prediction_path(base_conn, :index, %{
          "trip" => "trip",
          "page" => %{"offset" => 0, "limit" => 2}
        })
      )

    assert conn.assigns.data == Enum.take(@cr_predictions, 2)
  end

  test "includes all predictions for a stop", %{conn: conn} do
    new_prediction = %Prediction{
      stop_id: "1",
      route_id: "3",
      arrival_time: @latest_arrival
    }

    State.Prediction.new_state([new_prediction | @cr_predictions])

    for {params, expected} <- [
          {%{"stop" => "1"}, [@cr_prediction, new_prediction]},
          # doesn't have a stop in State.Stop
          {%{"stop" => "3"}, []},
          {%{"stop" => "1", "route" => "3"}, [new_prediction]},
          {%{"route" => "3"}, [new_prediction]}
        ] do
      conn = get(conn, "/predictions", params)
      assert conn.assigns.data == expected
    end
  end

  test "allows filtering by route_type", %{conn: conn} do
    prediction1 = %Prediction{
      stop_id: "1",
      route_id: "red",
      arrival_time: @latest_arrival
    }

    prediction2 = %Prediction{
      stop_id: "1",
      route_id: "2",
      arrival_time: @latest_arrival
    }

    route2 = %Model.Route{
      id: "2",
      type: 2,
      sort_order: 1,
      description: "Second Route",
      short_name: "Second",
      long_name: "Second"
    }

    State.Route.new_state([route2, @route])
    State.Prediction.new_state([prediction1, prediction2])

    for {params, expected} <- [
          {%{"stop" => "1"}, [prediction1, prediction2]},
          {%{"stop" => "1", "route_type" => "2"}, [prediction2]},
          {%{"stop" => "1", "route_type" => "1,2"}, [prediction1, prediction2]}
        ] do
      conn = get(conn, "/predictions", params)
      assert Enum.sort(conn.assigns.data) == Enum.sort(expected)
    end
  end

  test "versions before 2021-01-09 allow an unused `date` filter", %{conn: conn} do
    conn = assign(conn, :api_version, "2021-01-09")
    resp = get(conn, "/predictions", stop: @stop.id, date: "2020-01-01")
    assert json_response(resp, 400)

    conn = assign(conn, :api_version, "2020-05-01")
    resp = get(conn, "/predictions", stop: @stop.id, date: "2020-01-01")
    assert json_response(resp, 200)
  end

  test "versions before 2021-01-09 can filter using the old stop ID for Nubian", %{conn: conn} do
    nubn_predict = %Prediction{stop_id: "place-nubn", arrival_time: @latest_arrival}
    other_predict = %Prediction{stop_id: "other", arrival_time: @latest_arrival}
    predictions = [nubn_predict, other_predict]
    State.Stop.new_state([%Stop{id: "place-nubn"}, %Stop{id: "other"}])
    State.Prediction.new_state(predictions)

    conn = assign(conn, :api_version, "2020-05-01")

    assert Enum.sort(index_data(conn, %{"filter" => %{"stop" => "place-dudly,other"}})) ==
             Enum.sort(predictions)

    conn = assign(conn, :api_version, "2021-01-09")
    assert index_data(conn, %{"filter" => %{"stop" => "place-dudly,other"}}) == [other_predict]

    # ensure this also works *before* the transition has occurred

    prediction = %Prediction{stop_id: "place-dudly", arrival_time: @latest_arrival}
    State.Stop.new_state([%Stop{id: "place-dudly"}])
    State.Prediction.new_state([prediction])

    conn = assign(conn, :api_version, "2020-05-01")
    assert index_data(conn, %{"filter" => %{"stop" => "place-dudly"}}) == [prediction]

    conn = assign(conn, :api_version, "2021-01-09")
    assert index_data(conn, %{"filter" => %{"stop" => "place-dudly"}}) == [prediction]
  end

  test "versions before 2019-02-12 include Alewife platformed stops", %{conn: conn} do
    stops = [
      %Stop{id: "South Station", parent_station: "place-sstat"},
      %Stop{id: "South Station-02", parent_station: "place-sstat"},
      %Stop{id: "place-sstat", location_type: 1},
      %Stop{id: "70061", parent_station: "place-alfcl"},
      %Stop{id: "Alewife-01", parent_station: "place-alfcl"},
      %Stop{id: "place-alfcl", location_type: 1}
    ]

    predictions = [
      %Prediction{
        stop_id: "Alewife-01",
        route_id: "Red",
        arrival_time: @latest_arrival
      }
    ]

    State.Stop.new_state(stops)
    State.Prediction.new_state(predictions)

    for version <- ~w(2018-05-07 2018-07-23) do
      conn = assign(conn, :api_version, version)

      assert index_data(conn, %{"filter" => %{"stop" => "70061"}}) == predictions
    end

    conn = assign(conn, :api_version, "2019-02-12")
    assert index_data(conn, %{"filter" => %{"stop" => "70061"}}) == []
  end

  test "version 2018-05-07 returns platformed stops at South Station", %{conn: conn} do
    stops = [
      %Stop{id: "South Station", parent_station: "place-sstat"},
      %Stop{id: "South Station-02", parent_station: "place-sstat", platform_code: "2"},
      %Stop{id: "place-sstat", location_type: 1}
    ]

    prediction = %Prediction{
      stop_id: "South Station-02",
      route_id: "CR-Fitchburg",
      arrival_time: @latest_arrival
    }

    State.Stop.new_state(stops)
    State.Prediction.new_state([prediction])

    conn = assign(conn, :api_version, "2018-05-07")

    assert index_data(conn, %{"filter" => %{"stop" => "South Station,North Station"}}) == [
             prediction
           ]

    response =
      json_response(
        get(
          conn,
          prediction_path(conn, :index),
          stop: "South Station",
          include: "stop",
          fields: [prediction: "track"]
        ),
        200
      )

    assert [json] = response["data"]
    assert json["attributes"]["track"]
    assert [_] = response["included"]
  end

  test "includes all predictions for a route", %{conn: conn} do
    new_prediction = %Prediction{
      stop_id: "123",
      route_id: "2",
      arrival_time: @latest_arrival
    }

    State.Stop.new_state([@stop, %Stop{id: "123"}])
    State.Prediction.new_state([new_prediction | @cr_predictions])

    for {params, expected} <- [
          {%{"route" => "2"}, @cr_predictions ++ [new_prediction]},
          {%{"route" => "123"}, []},
          {%{"route" => "2", "stop" => "123"}, [new_prediction]},
          {%{"stop" => "123"}, [new_prediction]}
        ] do
      conn = get(conn, "/predictions", params)
      assert conn.assigns.data == expected
    end
  end

  test "includes all predictions for a trip", %{conn: conn} do
    new_prediction = %Prediction{
      stop_id: "123",
      route_id: "2",
      trip_id: "trip",
      arrival_time: @latest_arrival
    }

    State.Stop.new_state([@stop, %Stop{id: "123"}])
    State.Prediction.new_state([new_prediction | @cr_predictions])

    for {params, expected} <- [
          {%{"trip" => "trip"}, @cr_predictions ++ [new_prediction]},
          {%{"trip" => "other"}, []},
          {%{"trip" => "trip", "stop" => "123"}, [new_prediction]},
          {%{"stop" => "123"}, [new_prediction]}
        ] do
      conn = get(conn, "/predictions", params)
      assert conn.assigns.data == expected
    end
  end

  test "can filter by stop sequences", %{conn: conn} do
    for {params, expected} <- [
          {%{"stop" => "1", "stop_sequence" => "1"}, [@cr_prediction]},
          {%{"stop" => "1", "stop_sequence" => "1", "direction_id" => "0"}, []},
          {%{"stop" => "1", "stop_sequence" => "1", "direction_id" => "1"}, [@cr_prediction]},
          {%{"stop" => "1", "stop_sequence" => "2"}, []},
          {%{"stop" => "2", "stop_sequence" => "1"}, []},
          {%{"stop" => "1", "stop_sequence" => "1,2"}, [@cr_prediction]},
          {%{"stop" => "1,2", "stop_sequence" => "1,2"}, Enum.take(@cr_predictions, 2)},
          {%{"trip" => "trip", "stop_sequence" => "1"}, [@cr_prediction]},
          {%{"trip" => "trip", "stop_sequence" => "1,2"}, Enum.take(@cr_predictions, 2)}
        ] do
      conn = get(conn, "/predictions", params)
      assert {params, conn.assigns.data} == {params, expected}
    end
  end

  test "can filter by route pattern and stop", %{conn: conn} do
    trip1a = %Trip{
      id: "trip1a",
      route_id: "route",
      route_pattern_id: "1"
    }

    trip1b = %Trip{
      id: "trip1b",
      route_id: "route",
      route_pattern_id: "1"
    }

    trip2 = %Trip{
      id: "trip2",
      route_id: "route",
      route_pattern_id: "2"
    }

    p1 = %Prediction{
      stop_id: "1",
      route_id: "1",
      trip_id: "trip1a",
      direction_id: 1
    }

    p2 = %Prediction{
      stop_id: "2",
      route_id: "2",
      trip_id: "trip1b",
      direction_id: 1
    }

    p3 = %Prediction{
      stop_id: "1",
      route_id: "3",
      trip_id: "trip2",
      direction_id: 0
    }

    State.Trip.new_state([trip1a, trip1b, trip2])
    State.Prediction.new_state([p1, p2, p3])
    # re-fetch to get the predictions w/ the route_pattern_id
    [p1, p2, p3] = Enum.sort_by(State.Prediction.all(), & &1.trip_id)

    result = index_data(conn, %{"route_pattern" => "1"})
    assert Enum.sort_by(result, & &1.stop_id) == [p1, p2]

    result = index_data(conn, %{"route_pattern" => "2"})
    assert result == [p3]

    result = index_data(conn, %{"route_pattern" => "1", "stop" => "1"})
    assert result == [p1]

    result = index_data(conn, %{"route_pattern" => "2", "stop" => "1"})
    assert result == [p3]

    result = index_data(conn, %{"route_pattern" => "2", "stop" => "2"})
    assert result == []
  end

  test "can include a trip if it references an added trip", %{conn: conn} do
    State.Prediction.new_state([%Prediction{trip_id: "green"}])
    State.Trip.Added.new_state([%Trip{id: "green"}])

    conn = get(conn, "/predictions", trip: "green", include: "trip")
    response = json_response(conn, 200)
    assert [_ | _] = response["included"]
  end

  test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
    response =
      get(
        conn,
        prediction_path(conn, :index, %{
          "trip" => "trip",
          "page" => %{"offset" => 0, "limit" => Enum.count(@cr_predictions)}
        })
      )

    assert validate_resp_schema(response, schema, "Predictions")
  end

  test "does not include schedule by default", %{conn: conn} do
    conn = get(conn, prediction_path(conn, :index), trip: "trip")
    response = json_response(conn, 200)
    [prediction | _] = response["data"]
    refute "schedule" in Map.keys(prediction["relationships"])
  end

  test "can include schedule", %{conn: conn} do
    associated_schedule = %Model.Schedule{
      route_id: "route",
      trip_id: "trip",
      stop_id: "1",
      direction_id: 1,
      stop_sequence: 1,
      arrival_time: 45_000,
      departure_time: 45_000
    }

    prediction = %{@cr_prediction | stop_sequence: 1}
    State.Schedule.new_state([associated_schedule])
    State.Trip.new_state([%Trip{id: "trip", route_id: "route"}])
    State.Prediction.new_state([prediction])

    conn = get(conn, prediction_path(conn, :index), trip: "trip", include: "schedule")

    [schedule] =
      conn
      |> json_response(200)
      |> Map.get("included")

    for attr <- ["route", "stop", "trip"] do
      assert get_in(schedule, ["relationships", attr, "id"]) ==
               Map.get(prediction, String.to_atom(attr))
    end

    assert get_in(schedule, ["attributes", "stop_sequence"]) == prediction.stop_sequence
  end

  describe "including alerts" do
    defp build_alert(informed_entity) do
      {:ok, created_at, _} = DateTime.from_iso8601("2017-12-05T12:00:00Z")
      {:ok, updated_at, _} = DateTime.from_iso8601("2017-12-05T12:01:00Z")
      {:ok, end_of_day, _} = DateTime.from_iso8601("2017-12-05T23:59:59Z")

      %Model.Alert{
        id: "alert",
        effect: "CANCELLATION",
        cause: "ACCIDENT",
        url: "url",
        header: "header",
        short_header: "short header",
        banner: "banner",
        description: "description",
        created_at: created_at,
        updated_at: updated_at,
        severity: 10,
        active_period: [{created_at, end_of_day}],
        service_effect: "service effect",
        timeframe: "timeframe",
        lifecycle: "lifecycle",
        informed_entity: [
          informed_entity
        ]
      }
    end

    test "succeeds", %{conn: conn} do
      alert =
        build_alert(%{route: "red", trip: "trip2", stop: "1", direction_id: 1, route_type: 1})

      {:ok, arrival_time, _} = DateTime.from_iso8601("2017-12-05T15:00:00Z")

      different_route_prediction = %{
        @cr_prediction
        | route_id: "red",
          trip_id: "trip2",
          arrival_time: arrival_time
      }

      State.Alert.new_state([alert])
      State.Route.new_state([@route])
      State.Prediction.new_state([different_route_prediction, @cr_prediction])

      include_conn =
        get(
          conn,
          prediction_path(conn, :index),
          trip: "trip2",
          include: "alerts"
        )

      [response_alert] =
        include_conn
        |> json_response(200)
        |> Map.get("included")

      assert response_alert["type"] == "alert"
      assert response_alert["id"] == alert.id
    end

    test "does not return alerts when the include option is not provided and alerts exist", %{
      conn: conn
    } do
      alert =
        build_alert(%{route: "red", trip: "trip2", stop: "1", direction_id: 1, route_type: 1})

      different_route_prediction = %{@cr_prediction | route_id: "red", trip_id: "trip2"}
      State.Alert.new_state([alert])
      State.Prediction.new_state([different_route_prediction, @cr_prediction])

      no_include_conn =
        get(
          conn,
          prediction_path(conn, :index),
          trip: "trip2"
        )

      no_include_response =
        no_include_conn
        |> json_response(200)

      refute no_include_response["included"]
      [prediction | _] = no_include_response["data"]
      refute prediction["relationships"]["alerts"]
    end

    test "does not return alerts when no alerts exist", %{conn: conn} do
      different_route_prediction = %{@cr_prediction | route_id: "red", trip_id: "trip2"}
      State.Alert.new_state([])
      State.Prediction.new_state([different_route_prediction, @cr_prediction])

      include_nothing_conn =
        get(
          conn,
          prediction_path(conn, :index),
          trip: "trip2",
          include: "alerts"
        )

      response =
        include_nothing_conn
        |> json_response(200)

      refute response["included"]
      [prediction | _] = response["data"]
      assert prediction["relationships"]["alerts"]["data"] == []
    end
  end

  test "When including trip and trip id does not exist, result is same as if you did not include trip",
       %{conn: conn} do
    State.Prediction.new_state([%Prediction{trip_id: "green", route_id: "Red"}])
    get_conn = get(conn, "/predictions", filter: %{"route" => "Red"})

    get_conn_include_trip =
      get(conn, "/predictions", filter: %{"route" => "Red"}, include: "trip")

    response = json_response(get_conn, 200)
    include_response = json_response(get_conn_include_trip, 200)

    assert hd(response["data"])["relationships"]["trip"] ==
             hd(include_response["data"])["relationships"]["trip"]

    assert response["data"] == include_response["data"]
  end

  test "if the trip id can generate an Added trip, it's returned when included",
       %{conn: conn} do
    # run it 100 times since it's a race condition between State.Prediction and State.Trip.Added
    for _ <- 0..100 do
      State.Prediction.new_state([])
      # wait for State,Trip.Added to clear
      State.Trip.Added.last_updated()
      # need a stop ID to generate an Added trip
      State.Prediction.new_state([
        %Prediction{trip_id: "ADDED-1234", stop_id: "1", route_id: "Red"}
      ])

      conn = get(conn, "/predictions", filter: %{"route" => "Red"}, include: "trip")
      response = json_response(conn, 200)

      assert [%{"type" => "trip"}] = response["included"]
    end
  end

  test "When including trip and trip id does exist, behavior is normal", %{conn: conn} do
    State.Prediction.new_state([%Prediction{trip_id: "green", route_id: "Red"}])
    State.Trip.new_state([%Trip{id: "green", route_id: "Red"}])
    get_conn = get(conn, "/predictions", filter: %{"route" => "Red"})

    get_conn_include_trip =
      get(conn, "/predictions", filter: %{"route" => "Red"}, include: "trip")

    response = json_response(get_conn, 200)
    include_response = json_response(get_conn_include_trip, 200)

    assert hd(response["data"])["relationships"]["trip"] ==
             hd(include_response["data"])["relationships"]["trip"]

    assert response != include_response
  end

  test "state_module/0" do
    assert State.Prediction == ApiWeb.PredictionController.state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /predictions" do
      assert %{
               "/predictions" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{}
                   }
                 }
               }
             } = ApiWeb.PredictionController.swagger_path_index(%{})
    end
  end
end
