defmodule ApiWeb.ParamsTest do
  use ApiWeb.ConnCase, async: true
  doctest ApiWeb.Params
  alias ApiWeb.Params

  test "page filter with offset and limit" do
    assert Params.filter_opts(%{"page" => %{"offset" => 3}}, [:offset]) == [offset: 3]

    assert Params.filter_opts(%{"page" => %{"limit" => 10}}, [:limit]) == [limit: 10]

    assert Params.filter_opts(%{"page" => %{"offset" => 1, "limit" => 10}}, [:offset, :limit]) ==
             [limit: 10, offset: 1]

    assert Params.filter_opts(%{}, [:limit, :offset]) == []
  end

  test "multiple options are combined" do
    params = %{"sort" => "-name", "page" => %{"limit" => 3, "size" => 10}}

    assert Params.filter_opts(params, [:limit, :order_by]) == [
             order_by: [{:name, :desc}],
             limit: 3
           ]
  end

  test "integer values" do
    assert Params.integer_values("1,2,3") == [1, 2, 3]
    assert Params.integer_values("") == []
    assert Params.integer_values("1,hi,2") == [1, 2]
  end

  describe "route_types/1" do
    test "parses list of inputs into route type strings" do
      assert Params.route_types(%{"route_type" => "0,1,2"}) == [0, 1, 2]
    end

    test "returns empty list when no route_types" do
      assert Params.route_types(%{}) == []
    end

    test "doesn't add non integers to the list" do
      assert Params.route_types(%{"route_type" => "a,q,1"}) == [1]
    end
  end

  describe "filter_params/2" do
    setup %{conn: conn} do
      params = %{
        "stop" => "1,2,3",
        "trip" => "1,2,3",
        "filter" => %{
          "route" => "1,2,3",
          "stop" => "4,5,6"
        }
      }

      {:ok, %{params: params, conn: conn}}
    end

    test "filters items from 2nd arg", %{params: params, conn: conn} do
      assert Params.filter_params(params, ["route", "trip", "stop"], conn) ==
               {:ok,
                %{
                  "route" => "1,2,3",
                  "trip" => "1,2,3",
                  "stop" => "4,5,6"
                }}
    end

    test "returns error in case of unsupported filter", %{params: params, conn: conn} do
      assert Params.filter_params(params, ["route"], conn) == {:error, :bad_filter, ~w(stop trip)}

      conn = assign(conn, :api_version, "2019-02-12")
      assert Params.filter_params(params, ["route"], conn) == {:ok, %{"route" => "1,2,3"}}
    end
  end

  describe "validate_includes/2" do
    test "returns ok for valid includes", %{conn: conn} do
      assert Params.validate_includes(%{"include" => "stops,trips"}, ~w(stops routes trips), conn) ==
               {:ok, ~w(stops trips)}
    end

    test "returns error for invalid includes", %{conn: conn} do
      assert Params.validate_includes(%{"include" => "stops,routes"}, ~w(stops trips), conn) ==
               {:error, :bad_include, ~w(routes)}

      conn = assign(conn, :api_version, "2019-02-12")

      assert Params.validate_includes(%{"include" => "stops,routes"}, ~w(stops trips), conn) ==
               {:ok, ~w(stops routes)}
    end

    test "supports dot notation", %{conn: conn} do
      assert Params.validate_includes(%{"include" => "stops.id"}, ~w(stops routes trips), conn) ==
               {:ok, ~w(stops)}
    end
  end
end
