defmodule ApiWeb.ShapeController do
  @moduledoc """
  Controller for shapes. Filterable by:

  * route
  """
  use ApiWeb.Web, :api_controller
  alias State.Shape

  @filters ~w(route direction_id)s
  @pagination_opts ~w(offset limit)a

  def state_module, do: State.Shape

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    **NOTE:** `filter[route]` **MUST** be given for any shapes to be returned.

    List of shapes.

    #{swagger_path_description("/data/{index}")}
    """)

    common_index_parameters(__MODULE__)
    include_parameters(~w(route stops))
    filter_param(:id, name: :route, required: true)
    filter_param(:direction_id)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Shapes))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(_conn, params) do
    params
    |> Params.filter_params(@filters)
    |> do_filter(params)
  end

  defp do_filter(%{"route" => route_ids} = filtered_params, params) do
    route_ids = Params.split_on_comma(route_ids)
    direction_id = Params.direction_id(filtered_params)

    route_ids
    |> Shape.select_routes(direction_id)
    |> State.all(Params.filter_opts(params, @pagination_opts))
  end

  defp do_filter(_, _), do: {:error, :filter_required}

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Detail of a particular shape.

    #{swagger_path_description("/data")}
    """)

    include_parameters(~w(route stops))
    parameter(:id, :path, :string, "Unique identifier for shape")

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Shape))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
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
          Shape representing the stops to which a particular trip can go. Trips grouped under the same route can have \
          different shapes, and thus different stops. See \
          [GTFS `shapes.txt`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#shapestxt)
          """)

          attributes do
            name(
              :string,
              "User-facing name for shape. It may, but is not required to, be a headsign",
              example: "Dudley"
            )

            polyline(:string, """
            ## Encoding/Decoding

            [Encoded Polyline Algorithm Format](https://developers.google.com/maps/documentation/utilities/polylinealgorithm)

            ## Example Libraries

            * [Javascript](https://www.npmjs.com/package/polyline)
            * [Erlang](https://blog.kempkens.io/posts/encoding-and-decoding-polylines-with-erlang/)
            * [Elixir](https://hex.pm/packages/polyline)
            """)

            priority(
              :integer,
              """
              Representation of how important a shape is when choosing one for display. Higher number is higher \
              priority.  Negative priority is not important enough to show as they only **MAY** be used.
              """,
              example: 2
            )
          end

          direction_id_attribute()
          relationship(:route)
          relationship(:stops, type: :has_many)
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

    ### Stops

    If instead of getting the latitude and longitude directly, you want to show the stops in this shape use \
    `#{parent_pointer}/relationships/stops` to get the all the stop IDs or `include=stops` to include them in the \
    response.
    """
  end
end
