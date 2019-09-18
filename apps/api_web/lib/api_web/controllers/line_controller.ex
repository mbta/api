defmodule ApiWeb.LineController do
  @moduledoc """
  Controller for Lines. Filterable by:

  * id (multiple)
  """
  use ApiWeb.Web, :api_controller
  alias State.Line
  import ApiWeb.Params

  plug(ApiWeb.Plugs.ValidateDate)

  @filters ~w(id)s
  @pagination_opts ~w(offset limit order_by)a
  @includes ~w(routes)

  def state_module, do: State.Line

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    List of lines. A line is a combination of routes. This concept can be used to group similar routes \
    when displaying them to customers, such as for routes which serve the same trunk corridor or bus terminal.
    """)

    common_index_parameters(__MODULE__, :line)
    include_parameters(@includes)

    parameter(
      "filter[id]",
      :query,
      :string,
      "Filter by multiple IDs. #{comma_separated_list()}.",
      example: "1,2"
    )

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Lines))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    with {:ok, filtered} <- Params.filter_params(params, @filters, conn),
         {:ok, _includes} <- Params.validate_includes(params, @includes, conn) do
      lines =
        case filtered do
          %{"id" => ids} ->
            ids
            |> split_on_comma
            |> State.Line.by_ids()

          _ ->
            State.Line.all()
        end

      State.all(lines, pagination_opts(params, conn))
    else
      {:error, _, _} = error -> error
    end
  end

  defp pagination_opts(params, conn) do
    Params.filter_opts(params, @pagination_opts, conn, order_by: {:sort_order, :asc})
  end

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Single line, which represents a combination of routes.
    """)

    parameter(:id, :path, :string, "Unique identifier for a line")
    common_show_parameters(:line)
    include_parameters(@includes)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Lines))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(conn, %{"id" => id} = params) do
    case Params.validate_includes(params, @includes, conn) do
      {:ok, _includes} ->
        Line.by_id(id)

      {:error, _, _} = error ->
        error
    end
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      LineResource:
        resource do
          description("Line represents a combination of routes")

          attributes do
            short_name(
              :string,
              """
              Short, public-facing name for the group of routes represented in this line
              """,
              example: "CT2"
            )

            long_name(
              :string,
              """
              Lengthier, public-facing name for the group of routes represented in this line
              """,
              example: "Sullivan - Ruggles"
            )

            color(
              :string,
              """
              In systems that have colors assigned to lines, the route_color field defines a color \
              that corresponds to a line. The color must be provided as a six-character hexadecimal \
              number, for example, `00FFFF`.
              """,
              example: "FFFFFF"
            )

            text_color(
              :string,
              """
              This field can be used to specify a legible color to use for text drawn against a background \
              of line_color. The color must be provided as a six-character hexadecimal number, for example, \
              `FFD700`.
              """,
              example: "000000"
            )

            sort_order(:integer, "Lines sort in ascending order")
          end
        end,
      Lines: page(:LineResource),
      Line: single(:LineResource)
    }
  end
end
