defmodule ApiWeb.ShapeController do
  @moduledoc """
  Controller for shapes. Filterable only by route (required).
  """
  use ApiWeb.Web, :api_controller
  alias State.Shape

  @filters ~w(route)s
  @pagination_opts ~w(offset limit)a

  def state_module, do: State.Shape

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    **NOTE:** `filter[route]` **MUST** be given for any shapes to be returned.

    List of shapes.

    #{swagger_path_description("/data/{index}")}
    """)

    common_index_parameters(__MODULE__, :shape)
    filter_param(:id, name: :route, required: true)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Shapes))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    case Params.filter_params(params, filters(conn), conn) do
      {:ok, filtered} ->
        do_filter(filtered, params, conn)

      {:error, _, _} = error ->
        error
    end
  end

  defp filters(%{assigns: %{api_version: ver}}) when ver < "2021-01-09",
    do: ["direction_id" | @filters]

  defp filters(_), do: @filters

  defp do_filter(%{"route" => route_ids} = filtered_params, params, conn) do
    route_ids = Params.split_on_comma(route_ids)
    direction_id = Params.direction_id(filtered_params)

    route_ids
    |> Shape.select_routes(direction_id)
    |> State.all(Params.filter_opts(params, @pagination_opts, conn))
  end

  defp do_filter(_, _, _), do: {:error, :filter_required}

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Detail of a particular shape.

    #{swagger_path_description("/data")}
    """)

    parameter(:id, :path, :string, "Unique identifier for shape")
    common_show_parameters(:shape)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Shape))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(406, "Not Acceptable", Schema.ref(:NotAcceptable))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(_conn, %{"id" => id}) do
    Shape.by_primary_id(id)
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      ShapeResource:
        resource do
          description("""
          Sequence of geographic points representing a path vehicles will travel on a trip. See \
          [GTFS `shapes.txt`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#shapestxt).
          """)

          attributes do
            polyline(:string, """
            The sequence of points in \
            [Encoded Polyline Algorithm Format](https://developers.google.com/maps/documentation/utilities/polylinealgorithm).
            Libraries for decoding polylines are available in many languages, for example:

            * [Elixir](https://hex.pm/packages/polyline)
            * [JavaScript](https://www.npmjs.com/package/polyline)
            * [Python](https://pypi.org/project/polyline/)
            """)
          end
        end,
      Shape: single(:ShapeResource),
      Shapes: page(:ShapeResource)
    }
  end

  defp swagger_path_description(parent_pointer) do
    """
    ## Vertices

    ### World

    `#{parent_pointer}/attributes/polyline` is in \
    [Encoded Polyline Algorithm Format](https://developers.google.com/maps/documentation/utilities/polylinealgorithm), \
    which encodes the latitude and longitude of a sequence of points in the shape.
    """
  end
end
