defmodule ApiWeb.EventStream.DiffServerTest do
  @moduledoc false
  use ApiWeb.ConnCase
  import ApiWeb.EventStream.DiffServer
  import ApiWeb.Test.ProcessHelper

  @module ApiWeb.RouteController
  @moduletag timeout: 5_000

  setup %{conn: conn} do
    State.Route.new_state([%Model.Route{}])

    conn =
      conn
      |> Plug.Conn.fetch_query_params()
      |> Phoenix.Controller.put_view(ApiWeb.RouteView)

    {:ok, %{conn: conn}}
  end

  describe "stop/1" do
    test "stops the server", %{conn: conn} do
      {:ok, pid} = start_link({conn, @module, []})
      stop(pid)

      assert_stopped(pid)
    end
  end

  describe "handle_info(:event, _)" do
    test "handles paged responses", %{conn: conn} do
      conn = %{conn | params: %{"page" => %{"limit" => "1"}}}
      {:ok, pid} = start_link({conn, @module, []})
      subscribe(pid)
      assert_receive {:events, [_]}
    end
  end

  describe "messages to parent" do
    setup %{conn: conn} do
      {:ok, pid} = start_link({conn, @module, []})
      subscribe(pid)
      {:ok, %{pid: pid}}
    end

    test "receives a data message initially and after an update" do
      assert_receive {:events, [{"reset", _}]}
      refute_receive {:events, _}
      State.Route.new_state([])
      assert_receive {:events, [{"reset", _}]}
    end

    test "receives nothing if the data hasn't changed" do
      assert_receive {:events, [{"reset", _}]}
      State.Route.new_state([])
      assert_receive {:events, [{"reset", _}]}
      State.Route.new_state([])
      refute_receive {:events, [{"reset", _}]}
    end
  end

  describe "multiple parents" do
    @tag :capture_log
    setup %{conn: conn} do
      {:ok, pid} = start_link({conn, @module, []})
      {:ok, agent} = Agent.start_link(fn -> subscribe(pid) end)
      {:ok, %{pid: pid, agent: agent}}
    end

    @tag :capture_log
    test "subscriptions can also be removed", %{pid: pid} do
      subscribe(pid)
      assert_receive {:events, _}
      unsubscribe(pid)
      State.Route.new_state([])
      refute_receive {:events, [{"reset", _}]}
      assert Process.alive?(pid)
    end

    @tag :capture_log
    test "when all subscriptions are removed, the server stops", %{pid: pid, agent: agent} do
      Agent.get(agent, fn _ -> unsubscribe(pid) end)
      unsubscribe(pid)
      assert_stopped(pid)
    end

    @tag :capture_log
    test "new subscriptions receive the current data", %{pid: pid} do
      subscribe(pid)
      assert_receive {:events, _}
    end
  end

  describe "error messages" do
    test "responds with an error if something wrong happens", %{conn: conn} do
      {:ok, pid} = start_link({conn, ApiWeb.TripController, []})
      subscribe(pid)
      assert_receive {:error, _}
      assert_stopped(pid)
    end
  end

  describe "parent dying" do
    @tag :capture_log
    test "when the parent dies, the Server stops", %{conn: conn} do
      {:ok, pid} = start_link({conn, @module, []})

      {:ok, agent} =
        Agent.start_link(fn ->
          subscribe(pid)
        end)

      :ok = Agent.stop(agent)
      assert_stopped(pid)
    end
  end

  describe "diff_events/2" do
    test "returns added/updated/removed data from the JSON-API responses" do
      # keep some same data to avoid the "reset" check
      sames = for i <- 1..2, do: %{"type" => "prediction", "id" => "same_#{i}"}

      previous = [
        pred1 = %{"type" => "prediction", "id" => "1"},
        %{"type" => "prediction", "id" => "2"}
        | sames
      ]

      current = [
        stop1 = %{"type" => "stop", "id" => "1"},
        pred2_new = %{"type" => "prediction", "id" => "2", "attributes" => %{}}
        | sames
      ]

      assert [{"add", add_stop1}, {"update", update_pred2}, {"remove", remove_pred1}] =
               diff_events(previous, current)

      assert Jason.decode!(add_stop1) == stop1
      assert Jason.decode!(update_pred2) == pred2_new
      assert Jason.decode!(remove_pred1) == pred1
    end
  end
end
