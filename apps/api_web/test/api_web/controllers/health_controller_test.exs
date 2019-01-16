defmodule ApiWeb.HealthControllerTest do
  use ApiWeb.ConnCase

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "defaults to 503", %{conn: conn} do
    State.Alert.new_state([])
    State.Schedule.new_state([])
    State.StopsOnRoute.update!()
    conn = get(conn, health_path(conn, :index))
    assert json_response(conn, 503)
  end
end
