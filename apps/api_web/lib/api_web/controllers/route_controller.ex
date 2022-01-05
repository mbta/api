defmodule ApiWeb.RouteController do
  @moduledoc """
  Controller for Routes. Filterable by:

  * id
  * stop
  * date
  * direction_id
  * type
  """
  use ApiWeb.Web, :api_controller
  alias State.{Route, RoutesByService, RoutesPatternsAtStop, ServiceByDate}

  @filters ~w(id stop type direction_id date)
  @pagination_opts [:offset, :limit, :order_by]
  @includes_show ~w(line route_patterns)
  @includes_index ~w(stop) ++ @includes_show

  def state_module, do: State.Route

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    List of routes.

    #{swagger_path_description("/data/{index}")}
    """)

    common_index_parameters(__MODULE__, :route)

    include_parameters(
      @includes_index,
      description: "`stop` can only be included when `filter[stop]` is also specified."
    )

    filter_param(:stop_id)

    parameter(
      "filter[type]",
      :query,
      :string,
      """
      #{route_type_description()}

      Multiple `route_type` #{comma_separated_list()}.
      """,
      example: 0
    )

    filter_param(
      :direction_id,
      desc:
        "When combined with stop_id, filters by routes which stop at that stop when traveling in a particular direction"
    )

    filter_param(:date, description: "Filter by date that route is active")

    parameter(
      "filter[id]",
      :query,
      :string,
      "Filter by multiple IDs. Multiple IDs #{comma_separated_list()}.",
      example: "1,2"
    )

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Routes))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    with {:ok, filtered} <- Params.filter_params(params, @filters, conn) do
      filtered
      |> format_filters()
      |> expand_stops_filter(:stops, conn.assigns.api_version)
      |> do_filter()
      |> filter_hidden(filtered)
      |> State.all(pagination_opts(params, conn))
    else
      {:error, _, _} = error -> error
    end
  end

  defp format_filters(filters) do
    filters
    |> Enum.flat_map(&do_format_filter/1)
    |> Enum.into(%{})
  end

  defp do_format_filter({"id", ids}) do
    %{ids: Params.split_on_comma(ids)}
  end

  defp do_format_filter({"stop", stops}) do
    %{stops: Params.split_on_comma(stops)}
  end

  defp do_format_filter({"date", date_str}) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> %{service_ids: ServiceByDate.by_date(date)}
      {:error, _} -> []
    end
  end

  defp do_format_filter({"direction_id", direction_id}) do
    case Params.direction_id(%{"direction_id" => direction_id}) do
      nil -> []
      parsed_direction_id -> %{direction_id: parsed_direction_id}
    end
  end

  defp do_format_filter({"type", types_str}) do
    types_str
    |> Params.split_on_comma()
    |> Enum.flat_map(fn param ->
      case Params.int(param) do
        nil -> []
        value -> [value]
      end
    end)
    |> case do
      [] -> []
      [_ | _] = types -> %{type: types}
    end
  end

  defp do_filter(%{ids: ids}) do
    Route.by_ids(ids)
  end

  defp do_filter(%{stops: _stops, type: types} = filters) do
    filters
    |> routes_at_stops()
    |> Enum.flat_map(fn id -> for type <- types, do: %{id: id, type: type} end)
    |> Route.select()
  end

  defp do_filter(%{service_ids: []}), do: []

  defp do_filter(%{service_ids: service_ids, type: types}),
    do: service_ids |> RoutesByService.for_service_ids_and_types(types) |> Route.by_ids()

  defp do_filter(%{stops: _stops} = filters) do
    filters
    |> routes_at_stops()
    |> Route.by_ids()
  end

  defp do_filter(%{type: type}) do
    Route.by_types(type)
  end

  defp do_filter(%{service_ids: service_ids}) do
    service_ids |> RoutesByService.for_service_ids() |> Route.by_ids()
  end

  defp do_filter(_filters) do
    Route.all()
  end

  defp routes_at_stops(%{stops: stops} = filters) do
    opts =
      filters
      |> Map.take([:direction_id, :service_ids])
      |> Enum.into([])

    RoutesPatternsAtStop.routes_by_family_stops(stops, opts)
  end

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Show a particular route by the route's id.

    #{swagger_path_description("/data")}
    """)

    parameter(:id, :path, :string, "Unique identifier for route")
    common_show_parameters(:route)
    include_parameters(@includes_show)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Route))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(406, "Not Acceptable", Schema.ref(:NotAcceptable))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(_conn, %{"id" => id}) do
    Route.by_id(id)
  end

  defp pagination_opts(params, conn) do
    Params.filter_opts(params, @pagination_opts, conn, order_by: {:sort_order, :asc})
  end

  defp filter_hidden({route_list, offsets}, filtered) do
    {filter_hidden(route_list, filtered), offsets}
  end

  defp filter_hidden(route_list, %{"id" => _ids}), do: route_list

  defp filter_hidden(route_list, _) do
    filtered = Enum.reject(route_list, &Route.hidden?/1)

    if filtered == [] do
      route_list
    else
      filtered
    end
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      RouteResource:
        resource do
          description("""
          Path a vehicle travels during service. See \
          [GTFS `routes.txt](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt) for the \
          base specification.
          """)

          attributes do
            description(
              :string,
              """
              Details about stops, schedule, and/or service.  See
              [GTFS `routes.txt` `route_desc`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).
              """,
              example: "Rapid Transit"
            )

            fare_class(
              :string,
              """
              Specifies the fare type of the route, which can differ from the service category.
              """,
              example: "Free"
            )

            long_name(
              :string,
              """
              The full name of a route. This name is generally more descriptive than the `short_name` and will \
              often include the route's destination or stop. See \
              [GTFS `routes.txt` `route_long_name`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).
              """,
              example: "Red Line"
            )

            short_name(
              :string,
              """
              This will often be a short, abstract identifier like "32", "100X", or "Green" that riders use to \
              identify a route, but which doesn't give any indication of what places the route serves. See \
              [GTFS `routes.txt` `route_short_name`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).
              """,
              example: "Red"
            )

            sort_order(:integer, "Routes sort in ascending order")
            type(:integer, route_type_description(), example: 1)

            color(
              :string,
              """
              A color that corresponds to the route, such as the line color \
              on a map." See \
              [GTFS `routes.txt` `route_color`]\
              (https://github.com/google/transit/blob/master/gtfs/spec/en/\
              reference.md#routestxt).
              """,
              example: "FFFFFF"
            )

            text_color(
              :string,
              """
              A legible color to use for text drawn against a background of \
              the route's `color` attribute. See \
              [GTFS `routes.txt` `route_text_color`]\
              (https://github.com/google/transit/blob/master/gtfs/spec/en/\
              reference.md#routestxt).
              """,
              example: "000000"
            )
          end

          direction_attribute(:direction_names, """
          The names of direction ids for this route in ascending ordering starting at `0` for the first index.
          """)

          direction_attribute(:direction_destinations, """
          The destinations for direction ids for this route in ascending ordering starting at `0` for the first index.
          """)
        end,
      Routes: page(:RouteResource),
      Route: single(:RouteResource)
    }
  end

  defp direction_attribute(schema, field, description) do
    nested = Schema.array(:string)
    nested = put_in(nested.items.description, description)
    nested = put_in(nested.items."x-nullable", true)
    put_in(schema.properties.attributes.properties[field], nested)
  end

  defp swagger_path_description(parent_pointer) do
    """
    ## Names and Descriptions

    There are 3 attributes with increasing details for naming and describing the route.

    1. `#{parent_pointer}/attributes/short_name`
    2. `#{parent_pointer}/attributes/long_name`
    3. `#{parent_pointer}/attributes/description`

    ## Directions

    `#{parent_pointer}/attributes/direction_names` is the only place to convert the `direction_id` used throughout the \
    rest of the API to human-readable names.

    ## Type

    `#{parent_pointer}/attributes/type` corresponds to \
    [GTFS `routes.txt` `route_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#routestxt).

    #{route_type_description()}
    """
  end
end
