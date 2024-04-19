defmodule ApiWeb.StopController do
  use ApiWeb.Web, :api_controller

  alias ApiWeb.LegacyStops
  alias State.Stop

  plug(ApiWeb.Plugs.ValidateDate)

  @filters ~w(id date direction_id latitude longitude radius route route_type location_type service)s
  @pagination_opts ~w(offset limit order_by distance)a
  @includes ~w(child_stops connecting_stops facilities parent_station recommended_transfers route)
  @show_includes ~w(child_stops connecting_stops facilities parent_station recommended_transfers)
  @nodoc_includes ~w(recommended_transfers)

  def state_module, do: State.Stop.Cache

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    List stops.

    #{swagger_path_description("/data/{index}")}

    ### Nearby

    The `filter[latitude]` and `filter[longitude]` can be used together to find any stops near that latitude and \
    longitude.  The distance is in degrees as if latitude and longitude were on a flat 2D plane and normal \
    Pythagorean distance was calculated.  Over the region MBTA serves, `0.02` degrees is approximately `1` mile. How \
    close is considered nearby, is controlled by `filter[radius]`, which default to `0.01` degrees (approximately a \
    half mile).
    """)

    common_index_parameters(__MODULE__, :stop, :include_distance)

    include_parameters(@includes -- @nodoc_includes,
      description:
        "Note that `route` can only be included if `filter[route]` is present and has exactly one `/data/{index}/relationships/route/data/id`."
    )

    filter_param(:date,
      description:
        "Filter by date when stop is in use. Will be ignored unless filter[route] is present. If filter[service] is present, this filter will be ignored."
    )

    filter_param(:direction_id)

    parameter("filter[latitude]", :query, :string, """
    Latitude in degrees North in the [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#A_new_World_Geodetic_System:_WGS.C2.A084) \
    coordinate system to search `filter[radius]` degrees around with `filter[longitude]`.
    """)

    parameter("filter[longitude]", :query, :string, """
    Longitude in degrees East in the [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#Longitudes_on_WGS.C2.A084) \
    coordinate system to search `filter[radius]` degrees around with `filter[latitude]`.
    """)

    parameter("filter[radius]", :query, :number, """
    The distance is in degrees as if latitude and longitude were on a flat 2D plane and normal Pythagorean distance \
    was calculated.  Over the region MBTA serves, `0.02` degrees is approximately `1` mile. Defaults to `0.01` \
    degrees (approximately a half mile).
    """)

    parameter("filter[id]", :query, :string, """
    Filter by `/data/{index}/id` (the stop ID). Multiple `/data/{index}/id` #{comma_separated_list()}.
    """)

    filter_param(:route_type)
    filter_param(:id, name: :route)

    parameter("filter[service]", :query, :string, """
    Filter by service_id for which stop is in use. Multiple service_ids #{comma_separated_list()}.
    """)

    parameter("filter[location_type]", :query, :string, """
    Filter by location_type https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#stopstxt. Multiple location_type #{comma_separated_list()}.
    """)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Stops))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    filter_opts = Params.filter_opts(params, @pagination_opts, conn)

    with :ok <- Params.validate_includes(params, @includes, conn),
         {:ok, filtered} <- Params.filter_params(params, @filters, conn),
         formatted = format_filters(filtered),
         :ok <- check_distance_filter(filter_opts, formatted) do
      formatted
      |> expand_stops_filter(:ids, conn.assigns.api_version)
      |> Stop.filter_by()
      |> State.all(filter_opts)
    end
  end

  defp check_distance_filter(%{order_by: order_by}, formatted_filters) do
    cond do
      not Keyword.has_key?(order_by, :distance) ->
        :ok

      match?(%{latitude: _, longitude: _}, formatted_filters) ->
        :ok

      true ->
        {:error, :distance_params}
    end
  end

  defp check_distance_filter(_, _) do
    :ok
  end

  defp format_filters(filters) do
    filters
    |> Enum.flat_map(&do_format_filter/1)
    |> Enum.into(%{})
  end

  defp do_format_filter({"date", date_string}) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        %{date: date}

      _ ->
        []
    end
  end

  defp do_format_filter({"service", service_string}) do
    case Params.split_on_comma(service_string) do
      [] ->
        []

      service_ids ->
        %{services: service_ids}
    end
  end

  defp do_format_filter({"route", route_string}) do
    case Params.split_on_comma(route_string) do
      [] ->
        []

      route_ids ->
        %{routes: route_ids}
    end
  end

  defp do_format_filter({"route_type", type_string}) do
    route_type_ids =
      type_string
      |> Params.split_on_comma()
      |> Enum.flat_map(fn type_id_string ->
        case Integer.parse(type_id_string) do
          {type_id, ""} ->
            [type_id]

          _ ->
            []
        end
      end)

    if route_type_ids == [] do
      []
    else
      %{route_types: route_type_ids}
    end
  end

  defp do_format_filter({"id", stop_ids}) do
    %{ids: Params.split_on_comma(stop_ids)}
  end

  defp do_format_filter({"direction_id", direction_id}) do
    case Params.direction_id(%{"direction_id" => direction_id}) do
      nil ->
        []

      parsed_direction_id ->
        %{direction_id: parsed_direction_id}
    end
  end

  defp do_format_filter({"location_type", type_string}) do
    location_types =
      type_string
      |> Params.split_on_comma()
      |> Enum.flat_map(fn type_id_string ->
        case Integer.parse(type_id_string) do
          {type_id, ""} ->
            [type_id]

          _ ->
            []
        end
      end)

    if location_types == [] do
      []
    else
      %{location_types: location_types}
    end
  end

  defp do_format_filter({key, value})
       when key in ["radius", "longitude", "latitude"] do
    case Float.parse(value) do
      {parsed_value, ""} ->
        %{String.to_existing_atom(key) => parsed_value}

      _ ->
        []
    end
  end

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Detail for a specific stop.

    #{swagger_path_description("/data")}
    """)

    parameter(:id, :path, :string, "Unique identifier for stop")
    common_show_parameters(:stop)
    include_parameters(@show_includes -- @nodoc_includes)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Stop))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(406, "Not Acceptable", Schema.ref(:NotAcceptable))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(conn, %{"id" => id} = params) do
    case Params.validate_includes(params, @show_includes, conn) do
      :ok ->
        [id]
        |> LegacyStops.expand(conn.assigns.api_version, only_renames: true)
        |> Enum.find_value(&Stop.by_id/1)

      {:error, _, _} = error ->
        error
    end
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      StopResource:
        resource do
          description(
            "Physical location where transit can pick-up or drop-off passengers. See https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt for more details and https://github.com/mbta/gtfs-documentation/blob/master/reference/gtfs.md#stopstxt for specific extensions."
          )

          attributes do
            name(
              :string,
              """
              Name of a stop or station in the local and tourist vernacular.  See \
              [GTFS `stops.txt` `stop_name](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt)
              """,
              example: "Parker St @ Hagen Rd"
            )

            description(
              :string,
              """
              Description of the stop. See [GTFS `stops.txt` `stop_desc`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
              """,
              example: "Alewife - Red Line",
              "x-nullable": true
            )

            address(
              :string,
              """
              A street address for the station. See [MBTA extensions to GTFS](https://docs.google.com/document/d/1RoQQj3_-7FkUlzFP4RcK1GzqyHp4An2lTFtcmW0wrqw/view).
              """,
              example: "Alewife Brook Parkway and Cambridge Park Drive, Cambridge, MA 02140",
              "x-nullable": true
            )

            platform_code(
              :string,
              """
              A short code representing the platform/track (like a number or letter). See [GTFS `stops.txt` `platform_code`](https://developers.google.com/transit/gtfs/reference/gtfs-extensions#stopstxt_1).
              """,
              example: "5",
              "x-nullable": true
            )

            platform_name(
              :string,
              """
              A textual description of the platform or track. See [MBTA extensions to GTFS](https://docs.google.com/document/d/1RoQQj3_-7FkUlzFP4RcK1GzqyHp4An2lTFtcmW0wrqw/view).
              """,
              example: "Red Line",
              "x-nullable": true
            )

            latitude(
              :number,
              """
              Latitude of the stop or station.  Degrees North, in the \
              [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#A_new_World_Geodetic_System:_WGS.C2.A084) \
              coordinate system. See \
              [GTFS `stops.txt` `stop_lat`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
              """,
              example: -71.194994
            )

            longitude(
              :number,
              """
              Longitude of the stop or station. Degrees East, in the \
              [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#Longitudes_on_WGS.C2.A084) coordinate \
              system. See
              [GTFS `stops.txt` `stop_lon`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
              """,
              example: 42.316115
            )

            wheelchair_boarding(
              %Schema{type: :integer, enum: [0, 1, 2]},
              """
              Whether there are any vehicles with wheelchair boarding or paths to stops that are \
              wheelchair acessible: 0, 1, 2.

              #{wheelchair_boarding("*")}
              """,
              example: 0
            )

            location_type(%Schema{type: :integer, enum: [0, 1, 2, 3]}, """
            The type of the stop.

            | Value | Type | Description |
            | - | - | - |
            | `0` | Stop | A location where passengers board or disembark from a transit vehicle. |
            | `1` | Station | A physical structure or area that contains one or more stops. |
            | `2` | Station Entrance/Exit | A location where passengers can enter or exit a station from the street. The stop entry must also specify a parent_station value referencing the stop ID of the parent station for the entrance. |
            | `3` | Generic Node | A location within a station, not matching any other location_type, which can be used to link together pathways defined in pathways.txt. |

            See also [GTFS `stops.txt` `location_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
            """)

            municipality(
              :string,
              "The municipality in which the stop is located.",
              example: "Cambridge",
              "x-nullable": true
            )

            on_street(
              :string,
              "The street on which the stop is located.",
              example: "Massachusetts Avenue",
              "x-nullable": true
            )

            at_street(
              :string,
              "The cross street at which the stop is located.",
              example: "Essex Street",
              "x-nullable": true
            )

            vehicle_type(
              :integer,
              """
              The type of transportation used at the stop. `vehicle_type` will be a valid routes.txt `route_type` value:

              #{route_type_description()}
              """,
              example: 3,
              "x-nullable": true
            )
          end

          relationship(:parent_station)
        end,
      Stop: single(:StopResource),
      Stops: page(:StopResource)
    }
  end

  defp swagger_path_description(parent_pointer) do
    """
    ## Accessibility

    #{wheelchair_boarding(parent_pointer)}

    ## Location

    ### World

    Use `#{parent_pointer}/attributes/latitude` and `#{parent_pointer}/attributes/longitude` to get the location of a \
    stop.

    ### Entrance

    The stop may be inside a station.  If `#{parent_pointer}/relationships/parent_station/data/id` is present, you \
    should look up the parent station (`/stops/{parent_id}`) and use its location to give direction first to the \
    parent station and then route from there to the stop.

    """
  end

  defp wheelchair_boarding(parent_pointer) do
    """
    Wheelchair boarding (`#{parent_pointer}/attributes/wheelchair_boarding`) corresponds to \
    [GTFS wheelchair_boarding](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt). The \
    MBTA handles parent station inheritance itself, so value can be treated simply:

    | Value | Meaning                                       |
    |-------|-----------------------------------------------|
    | `0`   | No Information                                |
    | `1`   | Accessible (if trip is wheelchair accessible) |
    | `2`   | Inaccessible                                  |
    """
  end

  def filters, do: @filters
end
