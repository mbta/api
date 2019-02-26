defmodule ApiWeb.ErrorView do
  use Phoenix.View,
    root: "lib/api_web/templates",
    namespace: ApiWeb

  alias JaSerializer.ErrorSerializer
  import ApiWeb.Router.Helpers, only: [portal_url: 2]

  def render("429.json" <> _, _assigns) do
    ErrorSerializer.format(%{
      code: "rate_limited",
      status: "429",
      source: %{parameter: "api_key"},
      detail:
        "You have exceeded your allowed usage rate. " <>
          "Visit #{portal_url(ApiWeb.Endpoint, :landing)} to register or " <>
          "to increase your limit."
    })
  end

  def render("403.json" <> _, _assigns) do
    ErrorSerializer.format(%{code: :forbidden, status: "403"})
  end

  def render("404.json" <> _, _assigns) do
    ErrorSerializer.format(%{
      code: :not_found,
      source: %{parameter: "id"},
      status: "404",
      title: "Resource Not Found"
    })
  end

  def render("400.json" <> _, %{error: :filter_required}) do
    ErrorSerializer.format(%{
      code: :bad_request,
      status: "400",
      detail: "At least one filter[] is required."
    })
  end

  def render("400.json" <> _, %{error: :only_route_type}) do
    ErrorSerializer.format(%{
      code: :bad_request,
      status: "400",
      detail: "filter[route_type] must be used in conjunction with another filter[]."
    })
  end

  def render("400.json" <> _, %{error: :distance_params}) do
    ErrorSerializer.format(%{
      code: :bad_request,
      status: "400",
      detail:
        "sort=distance must be used in conjunction with filter[latitude] and filter[longitude]"
    })
  end

  def render("400.json" <> _, %{error: :invalid}) do
    ErrorSerializer.format(%{
      code: :bad_request,
      status: "400",
      detail: "Invalid request."
    })
  end

  def render("400.json" <> _, %{error: :invalid_order_by}) do
    ErrorSerializer.format(%{
      code: :bad_request,
      status: "400",
      source: %{parameter: "sort"},
      detail: "Invalid sort key."
    })
  end

  def render("400.json" <> _, %{error: :allowed_domain}) do
    ErrorSerializer.format(%{
      code: :bad_request,
      status: "400",
      detail: "Origin did not match allowed domains list for this key."
    })
  end

  def render("400.json" <> _, %{error: :bad_filter}) do
    ErrorSerializer.format(%{
      code: :bad_request,
      status: "400",
      source: %{parameter: "filter"},
      detail: "Unsupported filter."
    })
  end

  def render("400.json" <> _, %{error: :bad_include}) do
    ErrorSerializer.format(%{
      code: :bad_request,
      status: "400",
      source: %{parameter: "include"},
      detail: "Unsupported include."
    })
  end

  def render("406.json" <> _, _assigns) do
    ErrorSerializer.format(%{code: :not_acceptable, status: "406"})
  end

  def render("500.json" <> _, _assigns) do
    ErrorSerializer.format(%{code: :internal_error, status: "500"})
  end

  def render("403.html", _assigns) do
    "Forbidden"
  end

  def render("404.html", _assigns) do
    "Resource not found"
  end

  def render("406.html", _assigns) do
    "Not acceptable"
  end

  def render("500.html", _assigns) do
    "Internal server error"
  end

  # In case no render clause matches or no
  # template is found, let's render it as 500
  def template_not_found(_template, assigns) do
    render("500.json-api", assigns)
  end
end
