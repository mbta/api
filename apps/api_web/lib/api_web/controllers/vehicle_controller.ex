defmodule ApiWeb.VehicleController do
  @moduledoc """
  Controller for Vehicles. Can be filtered by:

  * trip
  * route (optionally direction)
  """
  use ApiWeb.Web, :api_controller
  alias State.Vehicle

  @filters ~w(trip route direction_id id)s
  @pagination_opts ~w(offset limit order_by)a
  @includes ~w(trip stop route)

  def state_module, do: State.Vehicle

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Single vehicle (bus, ferry, or train)

    #{swagger_path_description("/data")}
    """)

    include_parameters()
    parameter(:id, :path, :string, "Unique identifier for a vehicle")

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Vehicle))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  @spec show_data(Plug.Conn.t(), %{String.t() => String.t()}) :: Model.Vehicle.t() | nil
  def show_data(_conn, %{"id" => id} = params) do
    with {:ok, _includes} <- Params.validate_includes(params, @includes) do
      State.Vehicle.by_id(id)
    else
      {:error, _, _} = error -> error
    end
  end

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    List of vehicles (buses, ferries, and trains)

    #{swagger_path_description("/data/{index}")}
    """)

    common_index_parameters(__MODULE__)
    include_parameters()

    parameter(
      "filter[id]",
      :query,
      :string,
      "Filter by multiple IDs. Multiple IDs #{comma_separated_list()}.",
      example: "1,2"
    )

    filter_param(:id, name: :trip)

    parameter("filter[route]", :query, :string, """
    Filter by route. If the vehicle is on a \
    [multi-route trip](https://groups.google.com/forum/#!msg/massdotdevelopers/1egrhNjT9eA/iy6NFymcCgAJ), it will be \
    returned for any of the routes. Multiple `route_id` #{comma_separated_list()}.
    """)

    filter_param(:direction_id)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Vehicles))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  @spec index_data(Plug.Conn.t(), %{}) :: [Model.Vehicle.t()]
  def index_data(conn, params) do
    params = backwards_compatible_params(conn.assigns.api_version, params)

    with {:ok, filtered} <- Params.filter_params(params, @filters),
         {:ok, _includes} <- Params.validate_includes(params, @includes) do
      filtered
      |> apply_filters()
      |> State.all(Params.filter_opts(params, @pagination_opts))
    else
      {:error, _, _} = error -> error
    end
  end

  defp backwards_compatible_params("2017-11-28", %{"sort" => "last_updated" <> _} = params) do
    Map.put(params, "sort", "updated_at")
  end

  defp backwards_compatible_params("2017-11-28", %{"sort" => "-last_updated" <> _} = params) do
    Map.put(params, "sort", "-updated_at")
  end

  defp backwards_compatible_params(_version, params) do
    params
  end

  defp apply_filters(%{"id" => id}) do
    id
    |> Params.split_on_comma()
    |> Vehicle.by_ids()
  end

  defp apply_filters(%{"trip" => trip}) do
    trip
    |> Params.split_on_comma()
    |> Vehicle.by_trip_ids()
  end

  defp apply_filters(%{"route" => route} = filters) do
    direction_id = Params.direction_id(filters)

    route
    |> Params.split_on_comma()
    |> Vehicle.by_route_ids_and_direction_id(direction_id)
  end

  defp apply_filters(_filters) do
    Vehicle.all()
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      VehicleResource:
        resource do
          description("Current state of a vehicle on a trip.")

          attributes do
            bearing(
              :integer,
              "Bearing, in degrees, clockwise from True North, i.e., 0 is North and 90 is East. This can be the compass bearing, or the direction towards the next stop or intermediate location. See [GTFS-realtime Position bearing](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-position).",
              example: 174
            )

            current_status(
              :string,
              """
              Status of vehicle relative to the stops. See [GTFS-realtime VehicleStopStatus](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-vehiclestopstatus).

              | _**Value**_       | _**Description**_                                                                                          |
              |-------------------|------------------------------------------------------------------------------------------------------------|
              | **INCOMING_AT**   | The vehicle is just about to arrive at the stop (on a stop display, the vehicle symbol typically flashes). |
              | **STOPPED_AT**    | The vehicle is standing at the stop.                                                                       |
              | **IN_TRANSIT_TO** | The vehicle has departed the previous stop and is in transit.                                              |

              """,
              example: "IN_TRANSIT_TO"
            )

            current_stop_sequence(
              :integer,
              "Index of current stop along trip. See [GTFS-realtime VehiclePosition current_stop_sequence](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-vehicleposition)",
              example: 8
            )

            label(
              :string,
              "User visible label, such as the one of on the signage on the vehicle.  See [GTFS-realtime VehicleDescriptor label](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-vehicledescriptor).",
              example: "1817"
            )

            updated_at(
              %Schema{type: :string, format: :"date-time"},
              "Time at which vehicle information was last updated. Format is ISO8601.",
              example: "2017-08-14T16:04:44-04:00"
            )

            latitude(
              :number,
              "Latitude of the vehicle's current position. Degrees North, in the [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#A_new_World_Geodetic_System:_WGS.C2.A084) coordinate system. See [GTFS-realtime Position latitude](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-position).",
              example: -71.27239990234375
            )

            longitude(
              :number,
              "Longitude of the vehicle's current position.  Degrees East, in the [WGS-84](https://en.wikipedia.org/wiki/World_Geodetic_System#Longitudes_on_WGS.C2.A084) coordinate system. See [GTFS-realtime Position longitude](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-position).",
              example: 42.32941818237305
            )

            speed(
              :number,
              "Speed that the vehicle is traveling in meters per second. See [GTFS-realtime Position speed](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-position).",
              example: 16
            )
          end

          direction_id_attribute()
          relationship(:trip)
          relationship(:stop)
          relationship(:route)
        end,
      Vehicle: single(:VehicleResource),
      Vehicles: page(:VehicleResource)
    }
  end

  defp include_parameters(schema) do
    ApiWeb.SwaggerHelpers.include_parameters(
      schema,
      ~w(trip stop route),
      description: """
      | include | Description                                                                                                                                                                                                                                                                                                                                                  |
      |---------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
      | `trip`  | The trip which the vehicle is currently operating.                                                                                                                                                                                                                                                                                                           |
      | `stop`  | The vehicle's current (when `current_status` is **STOPPED_AT**) or *next* stop.                                                                                                                                                                                                                                                                              |
      | `route` | The one route that is designated for that trip, as in GTFS `trips.txt`.  A trip might also provide service on other routes, identified by the MBTA's `multi_route_trips.txt` GTFS extension. `filter[route]` does consider the multi_route_trips GTFS extension, so it is possible to filter for one route and get a different route included in the response. |
      """
    )
  end

  defp swagger_path_description(parent_pointer) do
    """
    ## Direction

    ### World

    To figure out which way the vehicle is pointing at the location, use `#{parent_pointer}/attributes/bearing`.  This \
    can be the compass bearing, or the direction towards the next stop or intermediate location.

    ### Trip

    To get the direction around the stops in the trip use `#{parent_pointer}/attributes/direction_id`.

    ## Location

    ### World

    Use `#{parent_pointer}/attributes/latitude` and `#{parent_pointer}/attributes/longitude` to get the location of a \
    vehicle.

    ### Trip

    Use `#{parent_pointer}/attributes/current_stop_sequence` to get the stop number along the trip.  Useful for linear \
    stop indicators.  Position relative to the current stop is in `#{parent_pointer}/attributes/current_status`.

    ## Movement

    ### World

    Use `#{parent_pointer}/attributes/speed` to get the speed of the vehicle in meters per second.
    """
  end
end
