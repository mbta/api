defmodule ApiWeb.Plugs.ExperimentalFeaturesTest do
  import Phoenix.ConnTest
  use ApiWeb.ConnCase, async: true

  test "init" do
    assert ApiWeb.Plugs.ExperimentalFeatures.init([]) == []
  end

  describe ":experimental_features_enabled?" do
    test "set to true if x-enable-experimental-features header included", %{conn: conn} do
      conn = put_req_header(conn, "x-enable-experimental-features", "true")
      conn = get(conn, "/stops/")
      assert conn.assigns.experimental_features_enabled?
    end

    test "set to false if x-enable-experimental-features header absent", %{conn: conn} do
      conn = get(conn, "/stops/")
      refute conn.assigns.experimental_features_enabled?
    end
  end
end
