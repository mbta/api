defmodule ApiWeb.PredictionController.SortByArrivalTimeTest do
  @moduledoc false
  use ApiWeb.ConnCase

  alias Model.{Prediction, Stop}

  @route1 %Model.Route{
    id: "Green",
    type: 0
  }

  @route2 %Model.Route{
    id: "Blue",
    type: 1
  }

  @route3 %Model.Route{
    id: "3",
    type: 0
  }

  @stop %Stop{
    id: "1",
    parent_station: "parent"
  }
  @parent_stop %Stop{
    id: "parent",
    location_type: 1
  }

  # The specific NaiveDateTime structs are used below to provide coverage for
  # scenarios as described here: https://github.com/elixir-lang/elixir/issues/5181
  @cr_predictions [
    %Prediction{
      arrival_time: nil,
      stop_id: "1",
      route_id: "1",
      trip_id: "trip",
      direction_id: 1
    },
    %Prediction{
      arrival_time: DateTime.from_naive!(~N[2016-08-31T20:00:00], "Etc/UTC"),
      stop_id: "1",
      route_id: "1",
      trip_id: "trip",
      direction_id: 2
    },
    %Prediction{
      arrival_time: DateTime.from_naive!(~N[2016-09-01T01:00:00], "Etc/UTC"),
      stop_id: "1",
      route_id: "1",
      trip_id: "trip",
      direction_id: 3
    },
    %Prediction{
      arrival_time: DateTime.from_naive!(~N[2016-09-01T02:00:00], "Etc/UTC"),
      stop_id: "1",
      route_id: "1",
      trip_id: "trip",
      direction_id: 4
    }
  ]

  setup %{conn: conn} do
    # stop is needed since we look up parent stops
    State.Stop.new_state([@stop, @parent_stop])
    State.Route.new_state([@route1, @route2, @route3])
    State.Prediction.new_state(Enum.shuffle(@cr_predictions))
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "predictions are sorted by ascending arrival_time", %{conn: base_conn} do
    query = [
      filter: %{"stop" => "parent"},
      sort: "arrival_time"
    ]

    conn = get(base_conn, prediction_path(base_conn, :index, query))

    expected = Enum.sort_by(@cr_predictions, & &1.direction_id, &<=/2)
    assert conn.assigns.data == expected
  end

  test "predictions are sorted by descending arrival_time", %{conn: base_conn} do
    query = [
      filter: %{"stop" => "parent"},
      sort: "-arrival_time"
    ]

    conn = get(base_conn, prediction_path(base_conn, :index, query))

    expected = Enum.sort_by(@cr_predictions, & &1.direction_id, &>=/2)
    assert conn.assigns.data == expected
  end
end
