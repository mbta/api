defmodule ApiWeb.RoutePatternController do
  @moduledoc """
  Controller for Route Patterns. Filterable by:

  * id
  * date
  * direction_id
  * route_id
  * stop
  * canonical
  """
  use ApiWeb.Web, :api_controller
  alias State.{RoutePattern, RoutesByService, ServiceByDate, Trip}

  plug(:ensure_path_matches_version)

  @filters ~w(id canonical route direction_id stop date)
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

    common_index_parameters(__MODULE__, :route_pattern)

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
    filter_param(:stop_id, includes_children: true)
    filter_param(:canonical)
    filter_param(:date, description: "Filter by date that route pattern is active")

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
    with :ok <- Params.validate_includes(params, @includes, conn),
         {:ok, filtered} <- Params.filter_params(params, @filters, conn) do
      filtered
      |> format_filters()
      |> expand_stops_filter(:stop_ids, conn.assigns.api_version)
      |> reject_invalid_canonical_filter()
      |> RoutePattern.filter_by()
      |> State.all(pagination_opts(params, conn))
    else
      {:error, _, _} = error -> error
    end
  end

  defp reject_invalid_canonical_filter(filters)

  defp reject_invalid_canonical_filter(%{canonical: nil} = filters),
    do: Map.delete(filters, :canonical)

  defp reject_invalid_canonical_filter(filters), do: filters

  @spec format_filters(%{optional(String.t()) => String.t()}) :: RoutePattern.filters()
  defp format_filters(filters, acc \\ %{})

  defp format_filters(%{"id" => ids} = filters, acc) do
    new_acc = Map.put(acc, :ids, Params.split_on_comma(ids))

    filters
    |> Map.delete("id")
    |> format_filters(new_acc)
  end

  defp format_filters(%{"direction_id" => direction_id} = filters, acc) do
    new_acc = Map.put(acc, :direction_id, Params.direction_id(%{"direction_id" => direction_id}))

    filters
    |> Map.delete("direction_id")
    |> format_filters(new_acc)
  end

  defp format_filters(%{"route" => route_ids} = filters, acc) do
    new_acc = Map.put(acc, :route_ids, Params.split_on_comma(route_ids))

    filters
    |> Map.delete("route")
    |> format_filters(new_acc)
  end

  defp format_filters(%{"date" => date} = filters, acc) do
    case process_date(date, acc) do
      :error ->
        filters
        |> Map.delete("date")
        |> format_filters(acc)

      new_acc ->
        filters
        |> Map.delete("date")
        |> format_filters(new_acc)
    end
  end

  defp format_filters(%{"stop" => stop_ids} = filters, acc) do
    new_acc = Map.put(acc, :stop_ids, Params.split_on_comma(stop_ids))

    filters
    |> Map.delete("stop")
    |> format_filters(new_acc)
  end

  defp format_filters(%{"canonical" => canonical} = filters, acc) do
    new_acc = Map.put(acc, :canonical, Params.canonical(canonical))

    filters
    |> Map.delete("canonical")
    |> format_filters(new_acc)
  end

  defp format_filters(_, acc) do
    acc
  end

  defp consolidate_route_ids(%{route_ids: [_ | _] = route_ids}, [_ | _] = date_specific_route_ids) do
    route_ids
    |> MapSet.new()
    |> MapSet.intersection(MapSet.new(date_specific_route_ids))
    |> MapSet.to_list()
  end

  defp consolidate_route_ids(_, date_specific_route_ids), do: date_specific_route_ids

  defp gather_trip_based_route_pattern_ids(
         %{ids: ids, date: _date, route_ids: [_ | _] = route_ids} = acc
       ) do
    acc
    |> Map.take([:date, :direction_id, :route_patterns])
    |> Map.put(:route_patterns, ids)
    |> Map.put(:routes, route_ids)
    |> gather_trip_based_route_pattern_ids(acc)
  end

  defp gather_trip_based_route_pattern_ids(%{date: _date, route_ids: [_ | _] = route_ids} = acc) do
    acc
    |> Map.take([:date, :direction_id, :route_patterns])
    |> Map.put(:routes, route_ids)
    |> gather_trip_based_route_pattern_ids(acc)
  end

  defp gather_trip_based_route_pattern_ids(acc), do: acc

  defp gather_trip_based_route_pattern_ids(filters, acc) do
    route_pattern_ids =
      filters
      |> Trip.filter_by()
      |> Enum.map(& &1.route_pattern_id)

    Map.put(acc, :ids, route_pattern_ids)
  end

  defp process_date(date_str, acc) do
    case process_date(date_str) do
      :error ->
        :error

      %{date: date, route_ids: date_specific_route_ids} ->
        filtered_route_ids = consolidate_route_ids(acc, date_specific_route_ids)

        acc
        |> Map.merge(%{route_ids: filtered_route_ids, date: date})
        |> gather_trip_based_route_pattern_ids()
    end
  end

  defp process_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        ids =
          date
          |> ServiceByDate.by_date()
          |> RoutesByService.for_service_ids()

        %{date: date, route_ids: ids}

      {:error, _} ->
        :error
    end
  end

  defp pagination_opts(params, conn) do
    Params.filter_opts(params, @pagination_opts, conn, order_by: {:sort_order, :asc})
  end

  swagger_path :show do
    get(path("route_pattern", :show))

    description("""
    Show a particular route_pattern by the route's id.

    #{@description}
    """)

    common_show_parameters(:route_pattern)

    parameter(:id, :path, :string, "Unique identifier for route_pattern")
    include_parameters()

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:RoutePattern))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(406, "Not Acceptable", Schema.ref(:NotAcceptable))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(conn, %{"id" => id} = params) do
    case Params.validate_includes(params, @includes, conn) do
      :ok ->
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
              | `5` | Canonical trip patterns. |
              """,
              enum: [0, 1, 2, 3, 4, 5]
            )

            sort_order(
              :integer,
              """
              Can be used to order the route patterns in a way which is ideal for presentation to customers.
              Route patterns with smaller sort_order values should be displayed before those with larger values.
              """
            )

            canonical(
              :boolean,
              """
              Indicates whether or not the route pattern can be considered canonical and the default set of stops
              for the given route and direction.

              | Value | Description |
              |-|-|
              | `true` | Route pattern should be considered canonical for this route in this direction. If branching regularly occurs, this route-direction may have more than one canonical pattern. |
              | `false` | Route pattern should be not considered canonical for this route in this direction. |
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
