defmodule ApiWeb.TripController do
  @moduledoc """
  Controller for Trips. Filterable by:

  * route IDs and/or date.
  * id (multiple)
  """
  use ApiWeb.Web, :api_controller
  alias State.Trip

  plug(ApiWeb.Plugs.ValidateDate)

  @filters ~w(id date direction_id route route_pattern name revenue)s
  @pagination_opts ~w(offset limit order_by)a
  @includes ~w(route vehicle service shape predictions route_pattern stops)

  def state_module, do: State.Trip.Added

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    **NOTE:** A id, route, route_pattern, or name filter **MUST** be present for any trips to be returned.

    List of trips, the journies of a particular vehicle through a set of stops on a primary `route` and zero or more \
    alternative `route`s that can be filtered on.

    #{swagger_path_description("/data/{index}")}
    """)

    common_index_parameters(__MODULE__, :trip)
    include_parameters()
    filter_param(:date, description: "Filter by trips on a particular date")
    filter_param(:direction_id)
    filter_param(:id, name: :route)
    filter_param(:revenue, desc: "Filter trips by revenue status.")

    parameter(
      "filter[route_pattern]",
      :query,
      :string,
      "Filter by route pattern IDs #{comma_separated_list()}.",
      example: "Red-1-0,Red-1-1"
    )

    parameter(
      "filter[id]",
      :query,
      :string,
      "Filter by multiple IDs. #{comma_separated_list()}.",
      example: "1,2"
    )

    parameter(
      "filter[name]",
      :query,
      :string,
      "Filter by multiple names. #{comma_separated_list()}.",
      example: "300,302"
    )

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Trips))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    with :ok <- Params.validate_includes(params, includes(conn), conn),
         {:ok, filtered} <- Params.filter_params(params, @filters, conn) do
      case format_filters(filtered) do
        filters when map_size(filters) > 0 ->
          filters
          |> Trip.filter_by()
          |> State.all(Params.filter_opts(params, @pagination_opts, conn))

        _ ->
          {:error, :filter_required}
      end
    else
      {:error, _, _} = error -> error
    end
  end

  # Format the params into domain values
  defp format_filters(filters) do
    filters
    |> Stream.flat_map(&do_format_filter/1)
    |> Enum.into(%{})
  end

  defp do_format_filter({"id", ids}) do
    %{ids: Params.split_on_comma(ids)}
  end

  defp do_format_filter({"date", date_string}) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        %{date: date}

      _ ->
        []
    end
  end

  defp do_format_filter({"route", route}) do
    case Params.split_on_comma(route) do
      [] ->
        []

      routes ->
        %{routes: routes}
    end
  end

  defp do_format_filter({"route_pattern", route_pattern}) do
    case Params.split_on_comma(route_pattern) do
      [] ->
        []

      route_patterns ->
        %{route_patterns: route_patterns}
    end
  end

  defp do_format_filter({"direction_id", direction_id}) do
    case Params.direction_id(%{"direction_id" => direction_id}) do
      nil ->
        []

      parsed_direction_id ->
        %{direction_id: parsed_direction_id}
    end
  end

  defp do_format_filter({"name", name}) do
    case Params.split_on_comma(name) do
      [] ->
        []

      names ->
        %{names: names}
    end
  end

  defp do_format_filter({"revenue", revenue}) do
    case Params.revenue(revenue) do
      :error -> []
      {:ok, val} -> %{revenue: val}
    end
  end

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Single trip - the journey of a particular vehicle through a set of stops

    #{swagger_path_description("/data")}
    """)

    parameter(:id, :path, :string, "Unique identifier for a trip")
    common_show_parameters(:trip)
    include_parameters()

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Trip))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(406, "Not Acceptable", Schema.ref(:NotAcceptable))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(conn, %{"id" => id} = params) do
    case Params.validate_includes(params, includes(conn), conn) do
      :ok ->
        Trip.by_primary_id(id)

      {:error, _, _} = error ->
        error
    end
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    wheelchair_accessibility_enum = Enum.to_list(0..2)
    bikes_allowed_enum = Enum.to_list(0..2)

    %{
      TripResource:
        resource do
          description("""
          Representation of the journey of a particular vehicle through a given set of stops. See \
          [GTFS `trips.txt`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt)
          """)

          attributes do
            headsign(
              :string,
              """
              The text that appears on a sign that identifies the trip's destination to passengers. See \
              [GTFS `trips.txt` `trip_headsign`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt).
              """,
              example: "Harvard"
            )

            name(
              :string,
              """
              The text that appears in schedules and sign boards to identify the trip to passengers, for example, to \
              identify train numbers for commuter rail trips. See \
              [GTFS `trips.txt` `trip_short_name`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt)
              """,
              example: "596"
            )

            block_id(
              :string,
              """
              ID used to group sequential trips with the same vehicle for a given service_id. See \
              [GTFS `trips.txt` `block_id`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt)
              """,
              example: "1070"
            )

            wheelchair_accessible(
              %Schema{type: :integer, enum: wheelchair_accessibility_enum},
              """
              Indicator of wheelchair accessibility: #{Enum.map_join(wheelchair_accessibility_enum, ", ", &"`#{&1}`")}

              #{wheelchair_accessibility("*")}
              """,
              example: 1
            )

            bikes_allowed(
              %Schema{type: :integer, enum: bikes_allowed_enum},
              """
              Indicator of whether or not bikes are allowed on this trip: #{Enum.map_join(bikes_allowed_enum, ", ", &"`#{&1}`")}

              #{bikes_allowed("*")}
              """,
              example: 1
            )
          end

          direction_id_attribute()
          relationship(:service)
          relationship(:route)
          relationship(:shape)
          relationship(:route_pattern)
          relationship(:occupancy)
        end,
      Trips: page(:TripResource),
      Trip: single(:TripResource),
      OccupancyResource:
        resource do
          description("""
          An expected or predicted level of occupancy for a given trip.
          """)

          attributes do
            status(
              %Schema{type: :string},
              occupancy_status_description(),
              example: "SOME_CROWDING"
            )

            percentage(
              %Schema{type: :integer},
              """
              Percentage of seats occupied.
              """,
              example: 55,
              "x-nullable": true
            )
          end
        end
    }
  end

  @spec includes(Plug.Conn.t()) :: [String.t()]
  defp includes(%{assigns: %{experimental_features_enabled?: true}}) do
    ["occupancies" | @includes]
  end

  defp includes(_) do
    @includes
  end

  defp include_parameters(schema) do
    ApiWeb.SwaggerHelpers.include_parameters(
      schema,
      @includes ++ ["occupancies"],
      description: """
      | include         | Description |
      |-----------------|-------------|
      | `route`         | The *primary* route for the trip. |
      | `vehicle`       | The vehicle on this trip. |
      | `service`       | The service controlling when this trip is active. |
      | `shape`         | The shape of the trip. |
      | `route_pattern` | The route pattern for the trip. |
      | `predictions`   | Predictions of when the `vehicle` on this `trip` will arrive at or depart from each stop on the route(s) on the `trip`. |
      | `stops`         | The stops this trip goes through. |
      | `occupancies`   | **EXPERIMENTAL:** The trip's static occupancy data. For information on experimental features, see: https://www.mbta.com/developers/v3-api/versioning.|
      """
    )
  end

  defp swagger_path_description(parent_pointer) do
    """
    ## Accessibility

    #{wheelchair_accessibility(parent_pointer)}

    ## Grouping

    Multiple trips **may** be grouped together using `#{parent_pointer}/attributes/block_id`. A block represents a \
    series of trips scheduled to be operated by the same vehicle.

    ## Naming

    There are 3 names associated with a trip.

    | API Field                   | GTFS              | Show users? |
    |-----------------------------|-------------------|-------------|
    | `/data/attributes/headsign` | `trip_headsign`   | Yes         |
    | `/data/attributes/name`     | `trip_short_name` | Yes         |
    | `/data/id`                  | `trip_id`         | No          |

    """
  end

  defp wheelchair_accessibility(parent_pointer) do
    """
    Wheelchair accessibility (`#{parent_pointer}/attributes/wheelchair_accessible`) \
    [as defined in GTFS](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt):

    | Value | Meaning                                            |
    |-------|----------------------------------------------------|
    | `0`   | No information                                     |
    | `1`   | Accessible (at stops allowing wheelchair_boarding) |
    | `2`   | Inaccessible                                       |
    """
  end

  defp bikes_allowed(parent_pointer) do
    """
    Bikes allowed (`#{parent_pointer}/attributes/bikes_allowed`) \
    [as defined in GTFS](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt):

    | Value | Meaning                                                                         |
    |-------|---------------------------------------------------------------------------------|
    | `0`   | No information                                                                  |
    | `1`   | Vehicle being used on this particular trip can accommodate at least one bicycle |
    | `2`   | No bicycles are allowed on this trip                                            |
    """
  end
end
