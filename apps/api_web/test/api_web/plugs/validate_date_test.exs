defmodule ApiWeb.Plugs.ValidateDateTest do
  use ApiWeb.ConnCase
  import ApiWeb.Plugs.ValidateDate

  @start_date ~D[2017-01-01]
  @end_date ~D[2017-02-01]
  @feed %Model.Feed{start_date: @start_date, end_date: @end_date}
  @opts init([])

  test "init/1" do
    assert init([])
  end

  describe "call/2" do
    setup %{conn: conn} do
      State.Feed.new_state(@feed)
      await_feed_ok()
      {:ok, conn: Plug.Conn.fetch_query_params(conn)}
    end

    test "with no date param, does nothing", %{conn: conn} do
      assert call(conn, @opts) == conn
    end

    test "with a valid date, does nothing", %{conn: conn} do
      conn = %{conn | query_params: %{"date" => Date.to_iso8601(@start_date)}}
      assert call(conn, @opts) == conn
      conn = %{conn | query_params: %{"date" => Date.to_iso8601(@end_date)}}
      assert call(conn, @opts) == conn
      conn = %{conn | query_params: %{"date" => "2017-01-15"}}
      assert call(conn, @opts) == conn
    end

    test "with an invalid date, returns a 400 and halts", %{conn: conn} do
      conn = %{conn | query_params: %{"date" => "2016-01-01"}}
      conn = call(conn, @opts)
      assert conn.halted
      assert conn.status == 400
      assert [error] = Jason.decode!(conn.resp_body)["errors"]

      assert error["meta"] == %{
               "start_date" => "2017-01-01",
               "end_date" => "2017-02-01",
               "version" => nil
             }
    end

    defp await_feed_ok do
      case State.Feed.get() do
        {:ok, _} ->
          :ok

        _ ->
          await_feed_ok()
      end
    end
  end
end
