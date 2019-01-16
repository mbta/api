defmodule ApiWeb.ModifiedHeadersTest do
  use ApiWeb.ConnCase

  test "modified headers are added to the response", %{conn: conn} do
    State.Stop.new_state([%Model.Stop{}])

    conn = get(conn, stop_path(conn, :index))
    assert [_] = get_resp_header(conn, "last-modified")
  end
end
