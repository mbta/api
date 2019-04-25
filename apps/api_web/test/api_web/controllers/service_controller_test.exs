defmodule ApiWeb.ServiceControllerTest do
  use ApiWeb.ConnCase

  import ApiWeb.ServiceController
  alias Model.Service

  setup tags do
    State.Service.new_state([
      %Service{
        id: "1",
        start_date: ~D[2018-12-03],
        end_date: ~D[2019-01-31],
        valid_days: [1, 2, 3, 4, 5],
        description: "Weekday schedule",
        schedule_name: "Weekday",
        schedule_type: "Weekday",
        schedule_typicality: 1,
        added_dates: [~D[2018-12-29], ~D[2018-12-30]],
        removed_dates: [~D[2019-01-01]]
      },
      %Service{
        id: "2",
        start_date: ~D[2018-12-01],
        end_date: ~D[2019-01-26],
        valid_days: [6],
        description: nil,
        schedule_name: nil,
        schedule_type: nil,
        schedule_typicality: 0,
        added_dates: [~D[2019-01-13]],
        removed_dates: []
      }
    ])

    {:ok, tags}
  end

  describe "index/2" do
    test "returns a 400 with no filters", %{conn: conn} do
      conn = get(conn, service_path(conn, :index))

      assert json_response(conn, 400)["errors"] == [
               %{
                 "status" => "400",
                 "code" => "bad_request",
                 "detail" => "At least one filter[] is required."
               }
             ]
    end

    test "returns 400 with invalid sort key", %{conn: conn} do
      conn = get(conn, service_path(conn, :index, %{"id" => "1,2", "sort" => "invalid"}))

      assert %{"errors" => [error]} = json_response(conn, 400)
      assert error["detail"] == "Invalid sort key."
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, service_path(conn, :index, %{"id" => "1,2"}))

      assert validate_resp_schema(response, schema, "Services")
    end
  end

  describe "show/2" do
    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, service_path(conn, :show, "2"))

      assert validate_resp_schema(response, schema, "Service")
    end

    test "does not allow filtering", %{conn: conn} do
      response = get(conn, service_path(conn, :show, "1", %{"filter[id]" => "1"}))
      assert json_response(response, 400)
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: swagger_schema
    } do
      conn = get(conn, service_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, swagger_schema, "NotFound")
    end
  end

  test "state_module/0" do
    assert State.Service == state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /services" do
      assert %{"/services" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /services/{id}" do
      assert %{
               "/services/{id}" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{},
                     "404" => %{}
                   }
                 }
               }
             } = swagger_path_show(%{})
    end
  end
end
