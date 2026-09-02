defmodule ApiWeb.TransferControllerTest do
  @moduledoc false
  use ApiWeb.ConnCase

  alias Model.{Stop, Transfer, Trip}

  @transfer1 %Transfer{
    from_stop_id: "place-north",
    to_stop_id: "place-south",
    transfer_type: 0,
    from_trip_id: "trip-A",
    to_trip_id: "trip-B",
    min_transfer_time: nil,
    min_walk_time: nil,
    min_wheelchair_time: nil,
    suggested_buffer_time: nil,
    wheelchair_transfer: 0
  }

  @transfer2 %Transfer{
    from_stop_id: "place-east",
    to_stop_id: "place-west",
    transfer_type: 2,
    from_trip_id: "trip-C",
    to_trip_id: "trip-D",
    min_transfer_time: 360,
    min_walk_time: 300,
    min_wheelchair_time: 420,
    suggested_buffer_time: 60,
    wheelchair_transfer: 1
  }

  @transfer3 %Transfer{
    from_stop_id: "place-north",
    to_stop_id: "place-east",
    transfer_type: 2,
    from_trip_id: nil,
    to_trip_id: nil,
    min_transfer_time: 120,
    min_walk_time: nil,
    min_wheelchair_time: nil,
    suggested_buffer_time: nil,
    wheelchair_transfer: 0
  }

  setup %{conn: conn} do
    State.Transfer.new_state([@transfer1, @transfer2, @transfer3])
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index_data/2" do
    test "returns 400 when no filters are provided", %{conn: conn} do
      conn = get(conn, "/transfers")

      assert json_response(conn, 400)["errors"] == [
               %{
                 "status" => "400",
                 "code" => "bad_request",
                 "detail" => "At least one filter[] is required."
               }
             ]
    end

    test "filters by trip", %{conn: conn} do
      conn = get(conn, "/transfers", %{"filter" => %{"from_trip" => "trip-A"}})
      data = json_response(conn, 200)["data"]
      assert length(data) == 1
      assert hd(data)["attributes"]["transfer_type"] == 0
    end

    test "filters by multiple trips (comma-separated)", %{conn: conn} do
      conn = get(conn, "/transfers", %{"filter" => %{"from_trip" => "trip-A,trip-C"}})
      data = json_response(conn, 200)["data"]
      assert length(data) == 2
    end

    test "returns empty list when no transfers match the filter", %{conn: conn} do
      conn = get(conn, "/transfers", %{"filter" => %{"from_trip" => "fake"}})
      assert json_response(conn, 200)["data"] == []
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, "/transfers", %{"filter" => %{"from_trip" => "trip-A"}})
      assert validate_resp_schema(response, schema, "Transfer")
    end

    test "response includes all documented attributes", %{conn: conn} do
      conn = get(conn, "/transfers", %{"filter" => %{"from_trip" => "trip-C"}})
      [transfer] = json_response(conn, 200)["data"]
      attrs = transfer["attributes"]

      assert Map.has_key?(attrs, "transfer_type")
      assert Map.has_key?(attrs, "min_transfer_time")
      assert Map.has_key?(attrs, "min_walk_time")
      assert Map.has_key?(attrs, "min_wheelchair_time")
      assert Map.has_key?(attrs, "suggested_buffer_time")
      assert Map.has_key?(attrs, "wheelchair_transfer")
    end

    test "response includes relationship links for stops and trips", %{conn: conn} do
      State.Stop.new_state([%Stop{id: "place-north"}, %Stop{id: "place-south"}])
      State.Trip.new_state([%Trip{id: "trip-A"}, %Trip{id: "trip-B"}])

      conn = get(conn, "/transfers", %{"filter" => %{"from_trip" => "trip-A"}})
      [transfer] = json_response(conn, 200)["data"]

      assert transfer["relationships"]["from_stop"]
      assert transfer["relationships"]["to_stop"]
      assert transfer["relationships"]["from_trip"]
      assert transfer["relationships"]["to_trip"]
    end

    test "response includes relationship data for stops and trips", %{conn: conn} do
      conn = get(conn, "/transfers", %{"filter" => %{"from_trip" => "trip-A"}})
      [transfer] = json_response(conn, 200)["data"]

      assert transfer["relationships"]["from_stop"]["data"]["id"] == "place-north"
      assert transfer["relationships"]["to_stop"]["data"]["id"] == "place-south"
      assert transfer["relationships"]["from_trip"]["data"]["id"] == "trip-A"
      assert transfer["relationships"]["to_trip"]["data"]["id"] == "trip-B"
    end

    test "pagination works", %{conn: conn} do
      conn =
        get(conn, "/transfers", %{
          "filter" => %{"from_trip" => "trip-A,trip-C"},
          "page" => %{"limit" => "1", "offset" => "0"}
        })

      response = json_response(conn, 200)
      assert length(response["data"]) == 1
      assert response["links"]["next"]
    end
  end

  describe "state_module/0" do
    test "returns State.Transfer" do
      assert ApiWeb.TransferController.state_module() == State.Transfer
    end
  end
end
