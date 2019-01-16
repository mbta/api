defmodule ApiWeb.ErrorViewTest do
  use ApiWeb.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  test "render 400 (invalid request)" do
    rendered = render(ApiWeb.ErrorView, "400.json", %{error: :invalid})
    only_route_type = render(ApiWeb.ErrorView, "400.json", %{error: :only_route_type})
    distance_params = render(ApiWeb.ErrorView, "400.json", %{error: :distance_params})
    assert [%{code: :bad_request}] = rendered["errors"]
    assert [%{code: :bad_request}] = only_route_type["errors"]
    assert [%{code: :bad_request}] = distance_params["errors"]
  end

  test "renders 404.json" do
    rendered = render(ApiWeb.ErrorView, "404.json", [])
    assert [%{code: :not_found}] = rendered["errors"]
  end

  test "render 406.json" do
    rendered = render(ApiWeb.ErrorView, "406.json", [])
    assert [%{code: :not_acceptable}] = rendered["errors"]
  end

  test "render 500.json" do
    rendered = render(ApiWeb.ErrorView, "500.json", [])
    assert [%{code: :internal_error}] = rendered["errors"]
  end

  test "render any other" do
    rendered = render(ApiWeb.ErrorView, "505.json", [])
    assert [%{code: :internal_error}] = rendered["errors"]
  end
end
