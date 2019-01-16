defmodule ApiWeb.StopViewTest do
  @moduledoc false
  use ApiWeb.ConnCase, async: true
  import Phoenix.View
  alias ApiWeb.StopView
  alias Model.Stop

  test "encodes the self link to be URL safe", %{conn: conn} do
    id = "River Works / GE Employees Only"
    expected = "River%20Works%20%2F%20GE%20Employees%20Only"
    stop = %Stop{id: id}
    rendered = render(StopView, "index.json-api", data: stop, conn: conn)
    assert rendered["data"]["links"]["self"] == "/stops/#{expected}"
  end

  describe "show.json-api" do
    test "doesn't include a route with a single include=route query param", %{conn: conn} do
      conn =
        conn
        |> Map.put(:params, %{"include" => "route"})
        |> Phoenix.Controller.put_view(StopView)
        |> ApiWeb.ApiControllerHelpers.split_include([])

      stop = %Stop{}
      rendered = render(StopView, "show.json-api", data: stop, conn: conn)
      refute rendered["data"]["relationships"]["route"]
    end
  end
end
