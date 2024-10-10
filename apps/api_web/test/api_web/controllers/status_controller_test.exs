defmodule ApiWeb.StatusControllerTest do
  use ApiWeb.ConnCase

  test "returns service metadata", %{conn: conn} do
    State.Feed.new_state(%Model.Feed{
      version: "TEST",
      start_date: ~D[2019-01-01],
      end_date: ~D[2019-02-01]
    })

    conn = get(conn, status_path(conn, :index))
    assert json = json_response(conn, 200)
    assert_attribute_key(json, "feed")
    assert_feed_key(json, "version")
    assert_feed_key(json, "start_date")
    assert_feed_key(json, "end_date")
    assert_attribute_key(json, "alert")
    assert_attribute_key(json, "facility")
    assert_attribute_key(json, "prediction")
    assert_attribute_key(json, "route")
    assert_attribute_key(json, "route_pattern")
    assert_attribute_key(json, "schedule")
    assert_attribute_key(json, "service")
    assert_attribute_key(json, "shape")
    assert_attribute_key(json, "stop")
    assert_attribute_key(json, "trip")
    assert_attribute_key(json, "vehicle")
  end

  def assert_attribute_key(json, attribute_key) do
    assert get_in(json, ["data", "attributes", attribute_key])
  end

  def assert_feed_key(json, feed_key) do
    assert get_in(json, ["data", "attributes", "feed", feed_key])
  end
end
