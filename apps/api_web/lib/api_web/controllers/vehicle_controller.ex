defmodule ApiWeb.VehicleController do
  @moduledoc """
  Controller for Vehicles. Can be filtered by:

  * trip
  * route (optionally direction)
  """
  use ApiWeb.Web, :api_controller
  alias State.Vehicle

  @filters ~w(trip route direction_id id label route_type revenue)s
  @pagination_opts ~w(offset limit order_by)a
  @includes ~w(trip stop route)

  def state_module, do: State.Vehicle

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Single vehicle (bus, ferry, or train)

    #{swagger_path_description("/data")}
    """)

    parameter(:id, :path, :string, "Unique identifier for a vehicle")
    common_show_parameters(:vehicle)
    include_parameters()

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Vehicle))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(406, "Not Acceptable", Schema.ref(:NotAcceptable))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  @spec show_data(Plug.Conn.t(), %{String.t() => String.t()}) :: Model.Vehicle.t() | nil
  def show_data(conn, %{"id" => id} = params) do
    case Params.validate_includes(params, @includes, conn) do
      :ok ->
        State.Vehicle.by_id(id)

      {:error, _, _} = error ->
        error
    end
  end

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    List of vehicles (buses, ferries, and trains)

    #{swagger_path_description("/data/{index}")}
    """)

    common_index_parameters(__MODULE__, :vehicle)
    include_parameters()

    parameter(
      "filter[id]",
      :query,
      :string,
      "Filter by multiple IDs. Multiple IDs #{comma_separated_list()}. Cannot be combined with any other filter.",
      example: "1,2"
    )

    parameter(
      "filter[trip]",
      :query,
      :string,
      "Filter by `/data/{index}/relationships/trip/data/id`. Multiple `/data/{index}/relationships/trip/data/id` #{comma_separated_list()}. Cannot be combined with any other filter."
    )

    parameter("filter[label]", :query, :string, """
    Filter by label. Multiple `label` #{comma_separated_list()}.
    """)

    parameter("filter[route]", :query, :string, """
    Filter by route. If the vehicle is on a \
    [multi-route trip](https://groups.google.com/forum/#!msg/massdotdevelopers/1egrhNjT9eA/iy6NFymcCgAJ), it will be \
    returned for any of the routes. Multiple `route_id` #{comma_separated_list()}.
    """)

    filter_param(:direction_id, desc: "Only used if `filter[route]` is also present.")
    filter_param(:route_type)
    filter_param(:revenue, desc: "Filter vehicles by revenue status.")

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

    with :ok <- Params.validate_includes(params, @includes, conn),
         {:ok, filtered} <- Params.filter_params(params, @filters, conn) do
      filtered
      |> apply_filters()
      |> State.all(Params.filter_opts(params, @pagination_opts, conn))
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

  # If no id or trip present, evaluate all remaining filters together
  defp apply_filters(%{} = filters) do
    filters
    |> Stream.flat_map(&do_format_filter(&1))
    |> Enum.into(%{})
    |> Vehicle.filter_by()
  end

  defp apply_filters(_filters) do
    Vehicle.all()
  end

  defp do_format_filter({key, string}) when key in ["label", "route"] do
    case Params.split_on_comma(string) do
      [] ->
        []

      values ->
        %{String.to_existing_atom("#{key}s") => values}
    end
  end

  defp do_format_filter({"route_type", route_type}) do
    case Params.integer_values(route_type) do
      [] ->
        []

      route_types ->
        %{route_types: route_types}
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

  defp do_format_filter({"revenue", revenue}) do
    case Params.revenue(revenue) do
      :error -> []
      {:ok, val} -> %{revenue: val}
    end
  end

  defp do_format_filter(_), do: []

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

            occupancy_status(
              :string,
              occupancy_status_description(),
              "x-nullable": true,
              example: "FEW_SEATS_AVAILABLE"
            )

            carriages(
              carriages_schema(),
              carriages_description(),
              "x-nullable": true,
              example: [
                %{
                  "label" => "some-carriage",
                  "occupancy_status" => "MANY_SEATS_AVAILABLE",
                  "occupancy_percentage" => 80
                }
              ]
            )

            revenue_status(
              :string,
              """
              | Value           | Description |
              |-----------------|-------------|
              | `"REVENUE"`     | Indicates that the associated trip is accepting passengers. |
              | `"NON_REVENUE"` | Indicates that the associated trip is not accepting passengers. |
              """,
              example: "REVENUE"
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
