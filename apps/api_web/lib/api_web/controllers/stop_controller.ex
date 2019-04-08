defmodule ApiWeb.StopController do
  use ApiWeb.Web, :api_controller
  alias State.Stop

  plug(ApiWeb.Plugs.ValidateDate)

  @filters ~w(id date direction_id latitude longitude radius route route_type)s
  @pagination_opts ~w(offset limit order_by distance)a
  @includes ~w(parent_station child_stops facilities route)

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

    common_index_parameters(__MODULE__, :include_distance)

    include_parameters(@includes,
      description:
        "Note that `route` can only be included if `filter[route]` is present and has exactly one `/data/{index}/relationships/route/data/id`."
    )

    filter_param(:date, description: "Filter by date when stop is in use")
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
    Filter by `/data/{index}/id` (the stop ID). Multiple `/data/{index}/id` #{
      comma_separated_list()
    }.
    """)

    filter_param(:route_type)
    filter_param(:id, name: :route)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Stops))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    filter_opts = Params.filter_opts(params, @pagination_opts)

    with true <- check_distance_filter?(filter_opts),
         {:ok, filtered} <- Params.filter_params(params, @filters, conn),
         {:ok, _includes} <- Params.validate_includes(params, @includes, conn) do
      filtered
      |> format_filters()
      |> Stop.filter_by()
      |> State.all(filter_opts)
    else
      false -> {:error, :distance_params}
      {:error, _, _} = error -> error
    end
  end

  defp check_distance_filter?(opts) when is_list(opts),
    do: opts |> Enum.into(%{}) |> (&check_distance_filter?(&1)).()

  defp check_distance_filter?(%{order_by: order_by} = filter_opts),
    do: check_distance_params(%{filter_opts | order_by: Enum.into(order_by, %{})})

  defp check_distance_filter?(_), do: true

  defp check_distance_params(%{order_by: %{distance: _}, latitude: _, longitude: _}), do: true
  defp check_distance_params(%{order_by: %{distance: _}}), do: false
  defp check_distance_params(_), do: true

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

    include_parameters(@includes,
      description:
        "Note that `route` can only be included if `filter[route]` is present and has exactly one `/data/{index}/relationships/route/data/id`. Use [/stops](#/Stop/ApiWeb_StopController_index) with `filter[id]` and `filter[route]` to include `route` with a specific stop."
    )

    parameter(:id, :path, :string, "Unique identifier for stop")

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Stop))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(conn, %{"id" => id} = params) do
    with {:ok, _includes} <- Params.validate_includes(params, @includes, conn) do
      Stop.by_id(id)
    else
      {:error, _, _} = error -> error
    end
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      StopResource:
        resource do
          description(
            "Physical location where transit can pick-up or drop-off passengers. See https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt for more details and http://realtime.mbta.com/Portal/Content/Documents/MBTA_GTFS_Documentation.html#stopstxt for specific extensions."
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
              [:string, :null],
              """
              Description of the stop. See [GTFS `stops.txt` `stop_desc`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
              """,
              example: "Alewife - Red Line"
            )

            address(
              [:string, :null],
              """
              A street address for the station. See [MBTA extensions to GTFS](https://docs.google.com/document/d/1RoQQj3_-7FkUlzFP4RcK1GzqyHp4An2lTFtcmW0wrqw/view).
              """,
              example: "Alewife Brook Parkway and Cambridge Park Drive, Cambridge, MA 02140"
            )

            platform_code(
              [:string, :null],
              """
              A short code representing the platform/track (like a number or letter). See [GTFS `stops.txt` `platform_code`](https://developers.google.com/transit/gtfs/reference/gtfs-extensions#stopstxt_1).
              """,
              example: "5"
            )

            platform_name(
              [:string, :null],
              """
              A textual description of the platform or track. See [MBTA extensions to GTFS](https://docs.google.com/document/d/1RoQQj3_-7FkUlzFP4RcK1GzqyHp4An2lTFtcmW0wrqw/view).
              """,
              example: "Red Line"
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

            location_type(%Schema{type: :integer, enum: [0, 1, 2]}, """
            The type of the stop.

            | Value | Type | Description |
            | - | - | - |
            | `0` | Stop | A location where passengers board or disembark from a transit vehicle. |
            | `1` | Station | A physical structure or area that contains one or more stops. |
            | `2` | Station Entrance/Exit | A location where passengers can enter or exit a station from the street. The stop entry must also specify a parent_station value referencing the stop ID of the parent station for the entrance. |

            See also [GTFS `stops.txt` `location_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stopstxt).
            """)
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
