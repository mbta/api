defmodule ApiWeb.LineView do
  use ApiWeb.Web, :api_view

  location("/lines/:id")

  # no cover
  attributes([
    :short_name,
    :long_name,
    :color,
    :text_color,
    :sort_order
  ])

  has_many(
    :routes,
    type: :route,
    serializer: ApiWeb.RouteView
  )

  def routes(%{id: line_id}, _conn) do
    State.Route.by_line_id(line_id)
  end
end
