defmodule ApiWeb.LineControllerTest do
  use ApiWeb.ConnCase

  import ApiWeb.LineController
  alias Model.{Line, Route}

  setup tags do
    State.Line.new_state([
      %Line{
        id: "1",
        short_name: "1st Line",
        long_name: "First Line",
        color: "00843D",
        text_color: "FFFFFF",
        sort_order: 1
      },
      %Line{
        id: "2",
        short_name: "2nd Line",
        long_name: "Second Line",
        color: "00843D",
        text_color: "FFFFFF",
        sort_order: 2
      }
    ])

    State.Route.new_state([
      %Route{
        id: "1-1",
        agency_id: "1",
        type: 1,
        line_id: "1",
        sort_order: 1
      },
      %Route{
        id: "1-2",
        agency_id: "1",
        type: 1,
        line_id: "1",
        sort_order: 2
      }
    ])

    {:ok, tags}
  end

  describe "index/2" do
    test "returns list of all lines with no filters", %{conn: conn} do
      conn = get(conn, line_path(conn, :index, %{"include" => "routes"}))

      assert json_response(conn, 200)["data"] == [
               %{
                 "attributes" => %{
                   "short_name" => "1st Line",
                   "long_name" => "First Line",
                   "color" => "00843D",
                   "text_color" => "FFFFFF",
                   "sort_order" => 1
                 },
                 "id" => "1",
                 "links" => %{
                   "self" => "/lines/1"
                 },
                 "type" => "line",
                 "relationships" => %{
                   "routes" => %{
                     "data" => [
                       %{"id" => "1-1", "type" => "route"},
                       %{"id" => "1-2", "type" => "route"}
                     ]
                   }
                 }
               },
               %{
                 "attributes" => %{
                   "short_name" => "2nd Line",
                   "long_name" => "Second Line",
                   "color" => "00843D",
                   "text_color" => "FFFFFF",
                   "sort_order" => 2
                 },
                 "id" => "2",
                 "links" => %{
                   "self" => "/lines/2"
                 },
                 "type" => "line",
                 "relationships" => %{"routes" => %{"data" => []}}
               }
             ]
    end

    test "returns 400 with invalid sort key", %{conn: conn} do
      conn = get(conn, line_path(conn, :index, %{"id" => "1,2", "sort" => "invalid"}))

      assert %{"errors" => [error]} = json_response(conn, 400)
      assert error["detail"] == "Invalid sort key."
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, line_path(conn, :index, %{"id" => "1,2"}))

      assert validate_resp_schema(response, schema, "Lines")
    end
  end

  describe "show/2" do
    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      response = get(conn, line_path(conn, :show, "2"))

      assert validate_resp_schema(response, schema, "Line")
    end

    test "does not allow filtering", %{conn: conn} do
      line = %Line{id: "1"}
      State.Line.new_state([line])

      response = get(conn, line_path(conn, :show, line.id, %{"filter[id]" => "1"}))
      assert json_response(response, 400)
    end

    test "returns an error with invalid includes", %{conn: conn} do
      conn = get(conn, line_path(conn, :show, "id"), include: "invalid")

      assert get_in(json_response(conn, 400), ["errors", Access.at(0), "source", "parameter"]) ==
               "include"
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: swagger_schema
    } do
      conn = get(conn, line_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, swagger_schema, "NotFound")
    end
  end

  test "state_module/0" do
    assert State.Line == state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /lines" do
      assert %{"/lines" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /lines/{id}" do
      assert %{
               "/lines/{id}" => %{
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
