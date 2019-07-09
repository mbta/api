defmodule ApiWeb.AlertControllerTest do
  @moduledoc false
  use ApiWeb.ConnCase
  alias ApiWeb.FacilityView
  alias State.{Alert, Facility}
  import ApiWeb.AlertController

  @alerts (for i <- 1..9 do
             informed_entity = %{facility: "#{i}"}

             activities =
               case i do
                 2 -> ["USING_ESCALATOR", "USING_WHEELCHAIR"]
                 3 -> ["USING_ESCALATOR"]
                 4 -> ["USING_WHEELCHAIR"]
                 _ -> ["BOARD", "EXIT", "RIDE"]
               end

             full_informed_entity =
               case activities do
                 [] -> informed_entity
                 _ -> Map.put(informed_entity, :activities, activities)
               end

             %Model.Alert{
               id: "#{i}",
               effect: "CANCELLATION",
               cause: "ACCIDENT",
               url: "url #{i}",
               header: "header #{i}",
               short_header: "short header #{i}",
               banner: "banner #{i}",
               description: "description #{i}",
               created_at: Timex.now(),
               updated_at: Timex.shift(Timex.now(), minutes: i),
               severity: 10,
               active_period: [{Timex.now(), Timex.end_of_day(Timex.now())}],
               service_effect: "service effect",
               timeframe: "timeframe",
               lifecycle: "lifecycle",
               informed_entity: [full_informed_entity]
             }
           end)

  defp insert_alerts!(alerts) do
    State.Alert.new_state(alerts)
    :ok
  end

  setup tags do
    State.Stop.new_state([%Model.Stop{}])
    State.Trip.new_state([])
    State.Route.new_state([])
    State.Schedule.new_state([])
    State.RoutesAtStop.update!()

    Facility.new_state([
      %Model.Facility{
        id: "6",
        long_name: "name",
        type: "ELEVATOR",
        stop_id: "place-qnctr"
      }
    ])

    insert_alerts!(@alerts)

    {:ok, tags}
  end

  describe "index_data/2" do
    test "returns all alerts", %{conn: conn} do
      assert index_data(conn, %{}) == State.Alert.all()
    end

    test "can filter (basic)", %{conn: conn} do
      data = index_data(conn, %{"activity" => "USING_WHEELCHAIR"})
      ids = for alert <- data, do: alert.id
      assert Enum.sort(ids) == ["2", "4"]
    end

    test "can filter by multiple IDs", %{conn: conn} do
      data = index_data(conn, %{"id" => "3,7,9", "activity" => "ALL"})
      ids = for alert <- data, do: alert.id
      assert Enum.sort(ids) == ["3", "7", "9"]
    end

    test "can filter by lifecycle", %{conn: conn} do
      refute index_data(conn, %{"lifecycle" => "lifecycle,other_lifecycle"}) == []
      assert index_data(conn, %{"lifecycle" => "other_lifecycle"}) == []
    end

    test "can filter by severity", %{conn: conn} do
      refute index_data(conn, %{"severity" => "9,10"}) == []
      assert index_data(conn, %{"severity" => "1,3"}) == []
      refute index_data(conn, %{"severity" => ""}) == []
      refute index_data(conn, %{}) == []
    end

    test "can filter by datetime", %{conn: conn} do
      now = DateTime.utc_now()
      tomorrow = Timex.shift(now, days: 1)
      refute index_data(conn, %{"datetime" => "NOW"}) == []
      refute index_data(conn, %{"datetime" => DateTime.to_iso8601(now)}) == []
      assert index_data(conn, %{"datetime" => DateTime.to_iso8601(tomorrow)}) == []
    end

    test "can filter by banner", %{conn: conn} do
      alerts =
        for i <- 1..2 do
          %Model.Alert{
            id: "filter_banner_test_#{i}",
            banner: (&if(&1 == 1, do: "some banner", else: nil)).(i),
            informed_entity: [%{facility: "1", activities: ["BOARD"]}]
          }
        end

      insert_alerts!(alerts)
      data = index_data(conn, %{"activity" => "BOARD", "banner" => "true"})
      ids = for alert <- data, do: alert.id
      assert Enum.sort(ids) == ["filter_banner_test_1"]

      data = index_data(conn, %{"activity" => "BOARD", "banner" => "false"})
      ids = for alert <- data, do: alert.id
      assert Enum.sort(ids) == ["filter_banner_test_2"]

      data = index_data(conn, %{"activity" => "BOARD", "banner" => "invalid"})
      ids = for alert <- data, do: alert.id
      assert Enum.sort(ids) == ["filter_banner_test_1", "filter_banner_test_2"]

      data = index_data(conn, %{"banner" => "true"})
      ids = for alert <- data, do: alert.id
      assert Enum.sort(ids) == ["filter_banner_test_1"]

      data = index_data(conn, %{"banner" => "false"})
      ids = for alert <- data, do: alert.id
      assert Enum.sort(ids) == ["filter_banner_test_2"]
    end

    test "returns an {:error, _} tuple with an invalid filter", %{conn: conn} do
      assert {:error, _} = index_data(conn, %{"direction_id" => "invalid"})
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, alert_path(conn, :index))

      assert validate_resp_schema(response, schema, "Alerts")
    end

    test "can be paginated and sorted", %{conn: conn} do
      alert3 = Enum.at(@alerts, 2)
      alert4 = Enum.at(@alerts, 3)
      alert6 = Enum.at(@alerts, 5)
      alert7 = Enum.at(@alerts, 6)
      params = %{"page" => %{"offset" => 2, "limit" => 2}}

      {[^alert3, ^alert4], _} = Alert.all(offset: 2, limit: 2, order_by: {:id, :asc})
      {[^alert7, ^alert6], _} = Alert.all(offset: 2, limit: 2, order_by: {:id, :desc})

      {data, _} = index_data(conn, Map.merge(params, %{"sort" => "id"}))
      assert data == [alert3, alert4]
      {data, _} = index_data(conn, Map.merge(params, %{"sort" => "-id"}))
      assert data == [alert7, alert6]
    end
  end

  describe "build_query/1" do
    test "can filter by multiple parts of an informed_entity" do
      params = %{
        "route_type" => "0,1",
        "stop" => "1,2",
        "route" => "2,3",
        "direction_id" => "1",
        "activity" => "BOARD,USING_WHEELCHAIR",
        "facility" => "4,5",
        "trip" => "5,6"
      }

      expected = %{
        route_types: [0, 1],
        stops: ~w(1 2),
        routes: ~w(2 3),
        direction_id: 1,
        activities: ~w(BOARD USING_WHEELCHAIR),
        facilities: ~w(4 5),
        trips: ~w(5 6)
      }

      actual = build_query(params)
      assert actual == expected
    end

    test "empty strings are treated as nil except for activities" do
      params = %{
        "route_type" => "",
        "stop" => "",
        "route" => "",
        "direction_id" => "",
        "activity" => "",
        "facility" => "",
        "trip" => ""
      }

      expected = %{
        route_types: [nil],
        stops: [nil],
        routes: [nil],
        direction_id: nil,
        activities: [],
        facilities: [nil],
        trips: [nil]
      }

      actual = build_query(params)
      assert actual == expected
    end

    test "multiple direction_ids are ignored" do
      params = %{
        "direction_id" => "0,1"
      }

      expected = %{}
      actual = build_query(params)
      assert actual == expected
    end
  end

  describe "show" do
    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, alert_path(conn, :show, 1))

      assert validate_resp_schema(response, schema, "Alert")
    end

    test "does not allow filtering", %{conn: conn} do
      alert = %Model.Alert{id: "1"}
      State.Alert.new_state([alert])

      response = get(conn, alert_path(conn, :show, alert.id, %{"filter[route]" => "1"}))
      assert json_response(response, 400)
    end

    test "returns an error with invalid includes", %{conn: conn} do
      conn = get(conn, alert_path(conn, :show, "id"), include: "invalid")

      assert get_in(json_response(conn, 400), ["errors", Access.at(0), "source", "parameter"]) ==
               "include"
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: swagger_shema
    } do
      conn = get(conn, alert_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, swagger_shema, "NotFound")
    end
  end

  test "can include a relationship", %{conn: conn} do
    conn = get(conn, alert_path(conn, :show, "6", include: "facilities"))
    response = json_response(conn, 200)

    template =
      FacilityView.render(
        "index.json-api",
        data: Facility.by_id("6"),
        conn: conn
      )

    assert [rendered_facility] = response["included"]
    assert rendered_facility == template["data"]
  end

  test "state_module/0" do
    assert State.Alert == ApiWeb.AlertController.state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /alerts" do
      assert %{"/alerts" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               ApiWeb.AlertController.swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /alerts/{id}" do
      assert %{
               "/alerts/{id}" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{},
                     "404" => %{}
                   }
                 }
               }
             } = ApiWeb.AlertController.swagger_path_show(%{})
    end
  end
end
