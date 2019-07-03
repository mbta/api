defmodule ApiWeb.ParamsTest do
  use ApiWeb.ConnCase, async: true
  doctest ApiWeb.Params
  alias ApiWeb.Params

  test "page filter with offset and limit", %{conn: conn} do
    conn = assign(conn, :api_version, "2019-02-12")
    assert Params.filter_opts(%{"page" => %{"offset" => 3}}, [:offset], conn) == [offset: 3]

    assert Params.filter_opts(%{"page" => %{"limit" => 10}}, [:limit], conn) == [limit: 10]

    assert Params.filter_opts(
             %{"page" => %{"offset" => 1, "limit" => 10}},
             [:offset, :limit],
             conn
           ) ==
             [limit: 10, offset: 1]

    assert Params.filter_opts(%{}, [:limit, :offset], conn) == []
  end

  test "multiple options are combined", %{conn: conn} do
    conn = assign(conn, :api_version, "2019-02-12")
    params = %{"sort" => "-name", "page" => %{"limit" => 3, "size" => 10}}

    assert Params.filter_opts(params, [:limit, :order_by], conn) == [
             order_by: [{:name, :desc}],
             limit: 3
           ]
  end

  test "filter_opts returns invalid sort on versions after 2019-07-01", %{conn: conn} do
    params = %{"sort" => "notavalidsort"}
    assert Params.filter_opts(params, [:order_by], conn) == [{:order_by, [{:invalid, :asc}]}]

    conn = assign(conn, :api_version, "2019-02-12")
    params = %{"sort" => "notavalidsort"}
    assert Params.filter_opts(params, [:order_by], conn) == []
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

  describe "filter_params/3" do
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
    end

    test "doesn't return error for unsupported filters for older key versions", %{
      params: params,
      conn: conn
    } do
      conn = assign(conn, :api_version, "2019-02-12")
      assert Params.filter_params(params, ["route"], conn) == {:ok, %{"route" => "1,2,3"}}
    end
  end

  describe "validate_includes/3" do
    test "returns ok for valid includes", %{conn: conn} do
      assert Params.validate_includes(%{"include" => "stops,trips"}, ~w(stops routes trips), conn) ==
               {:ok, ~w(stops trips)}
    end

    test "returns error for invalid includes", %{conn: conn} do
      assert Params.validate_includes(%{"include" => "stops,routes"}, ~w(stops trips), conn) ==
               {:error, :bad_include, ~w(routes)}

      assert Params.validate_includes(%{"include" => %{"bad" => ""}}, ~w(anything), conn) ==
               {:error, :bad_include, ~w(bad)}
    end

    test "doesn't return error for invalid includes for older key versions", %{conn: conn} do
      conn = assign(conn, :api_version, "2019-02-12")

      assert Params.validate_includes(%{"include" => "stops,routes"}, ~w(stops trips), conn) ==
               {:ok, ~w(stops routes)}
    end

    test "supports dot notation", %{conn: conn} do
      assert Params.validate_includes(%{"include" => "stops.id"}, ~w(stops routes trips), conn) ==
               {:ok, ~w(stops)}
    end

    test "doesn't return error for duplicate includes", %{conn: conn} do
      assert Params.validate_includes(
               %{"include" => "representative_trip.service,representative_trip.shape"},
               ~w(route representative_trip),
               conn
             ) == {:ok, ["representative_trip", "representative_trip"]}
    end
  end

  describe "validate_show_params/2" do
    test "returns ok for valid request", %{conn: conn} do
      assert :ok == Params.validate_show_params(%{"id" => "1"}, conn)
    end

    test "returns error when filter is present", %{conn: conn} do
      assert {:error, :bad_filter, _} =
               Params.validate_show_params(%{"id" => "1", "filter" => %{"id" => "3"}}, conn)
    end

    test "doesn't return error when using a filter for older key versions", %{conn: conn} do
      conn = assign(conn, :api_version, "2019-02-12")

      assert :ok == Params.validate_show_params(%{"id" => "1", "filter" => %{"id" => "3"}}, conn)
    end
  end
end
