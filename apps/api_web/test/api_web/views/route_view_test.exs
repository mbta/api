defmodule ApiWeb.RouteViewTest do
  use ApiWeb.ConnCase, async: true

  alias Model.Route

  test "attributes/2 uses struct's type and expected attributes" do
    route = %Route{
      id: "red",
      type: 1,
      description: "desc",
      fare_class: "Ferry",
      short_name: "short",
      long_name: "long",
      sort_order: 1,
      color: "some color",
      text_color: "some text color"
    }

    expected = %{
      type: 1,
      description: "desc",
      fare_class: "Ferry",
      short_name: "short",
      long_name: "long",
      direction_names: [nil, nil],
      direction_destinations: [nil, nil],
      sort_order: 1,
      color: "some color",
      text_color: "some text color"
    }

    assert ApiWeb.RouteView.attributes(route, %Plug.Conn{}) == expected
  end
end
