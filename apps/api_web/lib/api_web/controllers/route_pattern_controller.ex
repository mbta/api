defmodule ApiWeb.RoutePatternController do
  @moduledoc """
  Controller for Routes. Filterable by:

  * id
  * route_id
  """
  use ApiWeb.Web, :api_controller
  alias State.RoutePattern

  plug(:ensure_path_matches_version)

  @filters ~w(id route direction_id stop)
  @includes ~w(route representative_trip)
  @pagination_opts [:offset, :limit, :order_by]
  @description """
  Route patterns are used to describe the subsets of a route, representing different possible patterns of where trips may serve. For example, a bus route may have multiple branches, and each branch may be modeled as a separate route pattern per direction. Hierarchically, the route pattern level may be considered to be larger than the trip level and smaller than the route level.

  For most MBTA modes, a route pattern will typically represent a unique set of stops that may be served on a route-trip combination. Seasonal schedule changes may result in trips within a route pattern having different routings. In simple changes, such a single bus stop removed or added between one schedule rating and the next (for example, between the Summer and Fall schedules), trips will be maintained on the same route_pattern_id. If the changes are significant, a new route_pattern_id may be introduced.

  For Commuter Rail, express or skip-stop trips use the same route pattern as local trips. Some branches do have multiple route patterns when the train takes a different path. For example, `CR-Providence` has two route patterns per direction, one for the Wickford Junction branch and the other for the Stoughton branch.
  """

  def state_module, do: State.RoutePattern

  swagger_path :index do
    get(path("route_pattern", :index))

    description("""
    List of route patterns.

    #{@description}
    """)

    common_index_parameters(__MODULE__)

    include_parameters()

    parameter(
      "filter[id]",
      :query,
      :string,
      "Filter by multiple IDs. #{comma_separated_list()}.",
      example: "Red-1-0,Red-1-1"
    )

    filter_param(:id, name: :route)
    filter_param(:direction_id)
    filter_param(:id, name: :stop)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:RoutePattern))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  defp ensure_path_matches_version(conn, _) do
    if String.starts_with?(conn.request_path, "/route_patterns") or
         conn.assigns.api_version < "2019-07-01" do
      conn
    else
      conn
      |> put_status(:not_found)
      |> put_view(ApiWeb.ErrorView)
      |> render("404.json-api", [])
      |> halt()
    end
  end

  def index_data(conn, params) do
    with {:ok, filtered} <- Params.filter_params(params, @filters, conn),
         {:ok, _includes} <- Params.validate_includes(params, @includes, conn) do
      filtered
      |> format_filters()
      |> RoutePattern.filter_by()
      |> State.all(pagination_opts(params, conn))
    else
      {:error, _, _} = error -> error
    end
  end

  @spec format_filters(%{optional(String.t()) => String.t()}) :: RoutePattern.filters()
  defp format_filters(filters) do
    Map.new(filters, fn {key, value} ->
      case {key, value} do
        {"id", ids} ->
          {:ids, Params.split_on_comma(ids)}

        {"route", route_ids} ->
          {:route_ids, Params.split_on_comma(route_ids)}

        {"direction_id", direction_id} ->
          {:direction_id, Params.direction_id(%{"direction_id" => direction_id})}

        {"stop", stop_ids} ->
          {:stop_ids, Params.split_on_comma(stop_ids)}
      end
    end)
  end

  defp pagination_opts(params, conn) do
    params
    |> Params.filter_opts(@pagination_opts, conn)
    |> Keyword.put_new(:order_by, {:sort_order, :asc})
  end

  swagger_path :show do
    get(path("route_pattern", :show))

    description("""
    Show a particular route_pattern by the route's id.

    #{@description}
    """)

    parameter(:id, :path, :string, "Unique identifier for route_pattern")
    include_parameters()

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:RoutePattern))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(conn, %{"id" => id} = params) do
    case Params.validate_includes(params, @includes, conn) do
      {:ok, _includes} ->
        RoutePattern.by_id(id)

      {:error, _, _} = error ->
        error
    end
  end

  defp include_parameters(schema) do
    ApiWeb.SwaggerHelpers.include_parameters(
      schema,
      ~w(route representative_trip),
      description: """
      | include | Description |
      |-|-|
      | `route` | The route that this pattern belongs to. |
      | `representative_trip` | A trip that can be considered a canonical trip for the route pattern. This trip can be used to deduce a pattern's canonical set of stops and shape. |
      """
    )
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      RoutePatternResource:
        resource do
          description("""
          Information about the different variations of service that may be run within a single route_id, including when and how often they are operated.
          See \
          [GTFS `route_patterns.txt](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#route_patternstxt) \
          for the base specification.
          """)

          attributes do
            name(
              :string,
              """
              User-facing description of where trips on the route pattern serve.
              These names are published in the form
              Destination,
              Destination via Street or Landmark,
              Origin - Destination,
              or Origin - Destination via Street or Landmark.
              Note that names for bus and subway route patterns currently do not include the origin location,
              but will in the future.
              """,
              example: "Forge Park/495 - South Station via Fairmount"
            )

            time_desc(
              [:string, :null],
              """
              User-facing description of when the route pattern operate. Not all route patterns will include a time description
              """,
              example: "Early mornings only",
              "x-nullable": true
            )

            typicality(
              :integer,
              """
              Explains how common the route pattern is. For the MBTA, this is within the context of the entire route. Current valid values are:
              | Value | Description |
              |-|-|
              | `0` | Not defined |
              | `1` | Typical. Pattern is common for the route. Most routes will have only one such pattern per direction. A few routes may have more than 1, such as the Red Line (with one branch to Ashmont and another to Braintree); routes with more than 2 are rare. |
              | `2` | Pattern is a deviation from the regular route. |
              | `3` | Pattern represents a highly atypical pattern for the route, such as a special routing which only runs a handful of times per day. |
              | `4` | Diversions from normal service, such as planned detours, bus shuttles, or snow routes. |
              """,
              enum: [0, 1, 2, 3, 4]
            )

            sort_order(
              :integer,
              """
              Can be used to order the route patterns in a way which is ideal for presentation to customers.
              Route patterns with smaller sort_order values should be displayed before those with larger values.
              """
            )
          end

          direction_id_attribute()
          relationship(:route)
          relationship(:representative_trip)
        end,
      RoutePatterns: page(:RoutePatternResource),
      RoutePattern: single(:RoutePatternResource)
    }
  end
end
