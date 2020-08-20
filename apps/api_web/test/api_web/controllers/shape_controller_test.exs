defmodule ApiWeb.ShapeControllerTest do
  use ApiWeb.ConnCase
  import ApiWeb.ShapeController
  alias Model.Shape

  @pattern %Shape{
    id: "id",
    route_id: "route",
    direction_id: 1,
    priority: 1
  }

  @trip %Model.Trip{
    id: "trip",
    route_id: @pattern.route_id,
    direction_id: 1,
    shape_id: @pattern.id
  }

  def new_patterns(base_pattern) do
    name_first = %{base_pattern | name: "A"}
    name_second = %{base_pattern | name: "B"}
    [name_first, name_second, base_pattern]
  end

  setup _ do
    State.Shape.new_state([@pattern])
    State.Trip.new_state([@trip])
  end

  describe "show" do
    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      shapes =
        for i <- [1, 2] do
          %Shape{
            id: "#{i}",
            route_id: "route",
            direction_id: 1,
            priority: 1,
            name: "shape-#{i}",
            polyline: "polyline-#{i}"
          }
        end

      State.Shape.new_state(shapes)
      response = get(conn, shape_path(conn, :show, "1"))

      assert validate_resp_schema(response, schema, "Shape")
    end

    test "does not allow filtering", %{conn: conn} do
      shape = %Shape{id: "1"}
      State.Shape.new_state([shape])

      response = get(conn, shape_path(conn, :show, shape.id, %{"filter[route]" => "1"}))
      assert json_response(response, 400)
    end

    test "returns an error with invalid includes", %{conn: conn} do
      conn = get(conn, shape_path(conn, :show, "id"), include: "invalid")

      assert get_in(json_response(conn, 400), ["errors", Access.at(0), "source", "parameter"]) ==
               "include"
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: swagger_shema
    } do
      conn = get(conn, shape_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, swagger_shema, "NotFound")
    end
  end

  describe "show_data/2" do
    test "unknown ID returns nil", %{conn: conn} do
      refute show_data(conn, %{"id" => "unknown"})
    end

    test "ID returns the pattern", %{conn: conn} do
      assert show_data(conn, %{"id" => "id"}) == @pattern
    end
  end

  describe "index_data/2" do
    test "by default, returns an error", %{conn: conn} do
      assert index_data(conn, %{}) == {:error, :filter_required}
    end

    test "can filter by route", %{conn: conn} do
      for route <- ["route", "comma,separated,route"] do
        assert index_data(conn, %{"route" => route}) == [@pattern]
      end

      assert index_data(conn, %{"route" => "unknown"}) == []
    end

    test "versions before 2020-XX-XX can filter by direction_id", %{conn: conn} do
      conn = assign(conn, :api_version, "2020-XX-XX")
      expected = {:error, :bad_filter, ["direction_id"]}
      assert index_data(conn, %{"route" => "route", "direction_id" => "0"}) == expected

      conn = assign(conn, :api_version, "2020-05-01")
      assert index_data(conn, %{"route" => "route", "direction_id" => "1"}) == [@pattern]
      assert index_data(conn, %{"route" => "route", "direction_id" => "1,0"}) == [@pattern]
      assert index_data(conn, %{"route" => "route", "direction_id" => "0"}) == []
    end

    test "sorts patterns by primary, then name", %{conn: conn} do
      [name_first, name_second | _] = patterns = new_patterns(@pattern)

      patterns
      |> Enum.shuffle()
      |> State.Shape.new_state()

      assert index_data(conn, %{"route" => "route"}) == [
               @pattern,
               name_first,
               name_second
             ]
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      shapes =
        for i <- [1, 2] do
          %Shape{
            id: "#{i}",
            route_id: "route",
            direction_id: 1,
            priority: 1,
            name: "shape-#{i}",
            polyline: "polyline-#{i}"
          }
        end

      State.Shape.new_state(shapes)
      response = get(conn, shape_path(conn, :index, %{"filter[route]" => "route"}))

      assert validate_resp_schema(response, schema, "Shapes")
    end

    test "paginates data", %{conn: conn} do
      [name_first | _] = patterns = new_patterns(@pattern)

      patterns
      |> Enum.shuffle()
      |> State.Shape.new_state()

      params = %{"route" => "route", "page" => %{"offset" => 1, "limit" => 1}}
      {data, _} = index_data(conn, params)
      assert data == [name_first]
    end
  end

  test "state_module/0" do
    assert State.Shape == ApiWeb.ShapeController.state_module()
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /shapes" do
      assert %{"/shapes" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               ApiWeb.ShapeController.swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /shapes/{id}" do
      assert %{
               "/shapes/{id}" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{},
                     "404" => %{}
                   }
                 }
               }
             } = ApiWeb.ShapeController.swagger_path_show(%{})
    end
  end
end
