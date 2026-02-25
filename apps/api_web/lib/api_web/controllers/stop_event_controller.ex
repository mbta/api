defmodule ApiWeb.StopEventController do
  @moduledoc """
  Controller for Stop Events. Filterable by:

  * trip
  * stop
  * route
  * vehicle
  * direction_id
  """
  use ApiWeb.Web, :api_controller
  alias State.StopEvent

  @filters ~w(trip stop route vehicle direction_id)
  @includes ~w(trip stop route vehicle)
  @pagination_opts [:offset, :limit, :order_by]
  @description """
  Stop events represent the actual arrival and departure times of vehicles at stops along their trips.
  This is historical data showing when vehicles actually arrived at or departed from stops, as opposed
  to predictions or scheduled times.

  Each stop event contains:
  - The actual arrival time (as Unix epoch seconds)
  - The actual departure time (as Unix epoch seconds)
  - The stop sequence number
  - Whether the trip was a revenue trip

  Stop events are identified by a composite key of trip_id, route_id, vehicle_id, and stop_id.
  """

  def state_module, do: State.StopEvent

  swagger_path :index do
    get(path("stop_event", :index))

    description("""
    List of stop events.

    #{@description}
    """)

    common_index_parameters(__MODULE__, :stop_event)

    include_parameters()

    parameter(
      "filter[trip]",
      :query,
      :string,
      "Filter by trip ID. #{comma_separated_list()}.",
      example: "73885810"
    )

    parameter(
      "filter[stop]",
      :query,
      :string,
      "Filter by stop ID. #{comma_separated_list()}.",
      example: "2231"
    )

    parameter(
      "filter[route]",
      :query,
      :string,
      "Filter by route ID. #{comma_separated_list()}.",
      example: "64"
    )

    parameter(
      "filter[vehicle]",
      :query,
      :string,
      "Filter by vehicle ID. #{comma_separated_list()}.",
      example: "y2071"
    )

    filter_param(:direction_id)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:StopEvents))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    with :ok <- Params.validate_includes(params, @includes, conn),
         {:ok, filtered} <- Params.filter_params(params, @filters, conn) do
      filtered
      |> format_filters()
      |> StopEvent.filter_by()
      |> State.all(pagination_opts(params, conn))
    else
      {:error, _, _} = error -> error
    end
  end

  @spec format_filters(%{optional(String.t()) => String.t()}) :: StopEvent.filters()
  defp format_filters(filters, acc \\ %{})

  defp format_filters(%{"trip" => trip_ids} = filters, acc) do
    new_acc = Map.put(acc, :trip_ids, Params.split_on_comma(trip_ids))

    filters
    |> Map.delete("trip")
    |> format_filters(new_acc)
  end

  defp format_filters(%{"stop" => stop_ids} = filters, acc) do
    new_acc = Map.put(acc, :stop_ids, Params.split_on_comma(stop_ids))

    filters
    |> Map.delete("stop")
    |> format_filters(new_acc)
  end

  defp format_filters(%{"route" => route_ids} = filters, acc) do
    new_acc = Map.put(acc, :route_ids, Params.split_on_comma(route_ids))

    filters
    |> Map.delete("route")
    |> format_filters(new_acc)
  end

  defp format_filters(%{"vehicle" => vehicle_ids} = filters, acc) do
    new_acc = Map.put(acc, :vehicle_ids, Params.split_on_comma(vehicle_ids))

    filters
    |> Map.delete("vehicle")
    |> format_filters(new_acc)
  end

  defp format_filters(%{"direction_id" => direction_id} = filters, acc) do
    new_acc = Map.put(acc, :direction_id, Params.direction_id(%{"direction_id" => direction_id}))

    filters
    |> Map.delete("direction_id")
    |> format_filters(new_acc)
  end

  defp format_filters(_filters, acc) do
    acc
  end

  defp pagination_opts(params, conn) do
    opts =
      params
      |> Params.filter_opts(@pagination_opts, conn)

    if is_list(opts) do
      Keyword.put_new(opts, :order_by, {:id, :asc})
    else
      opts
      |> Map.to_list()
      |> Keyword.put_new(:order_by, {:id, :asc})
    end
  end

  swagger_path :show do
    get(path("stop_event", :show))

    description("""
    Show a particular stop event by its composite ID.

    #{@description}
    """)

    parameter(:id, :path, :string, "Unique identifier for stop event (trip_id-route_id-vehicle_id-stop_id)")
    include_parameters()

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:StopEvent))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(_conn, %{"id" => id}) do
    StopEvent.by_id(id)
  end

  defp include_parameters(schema) do
    ApiWeb.SwaggerHelpers.include_parameters(
      schema,
      @includes,
      description: """
      | include | Description |
      |-|-|
      | `trip` | The trip associated with this stop event. |
      | `stop` | The stop where the event occurred. |
      | `route` | The route associated with this stop event. |
      | `vehicle` | The vehicle that served this trip. |
      """
    )
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      StopEventResource:
        resource do
          description("""
          Actual arrival and departure times of vehicles at stops.
          """)

          attributes do
            vehicle_id(
              :string,
              """
              The vehicle ID that served this trip.
              """,
              example: "y2071"
            )

            start_date(
              :string,
              """
              The service date of the trip in YYYY-MM-DD format.
              """,
              example: "2026-02-24",
              format: :date
            )

            trip_id(
              :string,
              """
              The trip ID associated with this stop event.
              """,
              example: "73885810"
            )

            direction_id(
              :integer,
              """
              Direction in which the trip is traveling:
              - `0` - Travel in one direction (e.g. outbound travel)
              - `1` - Travel in the opposite direction (e.g. inbound travel)
              """,
              enum: [0, 1],
              example: 0
            )

            route_id(
              :string,
              """
              The route ID associated with this stop event.
              """,
              example: "64"
            )

            start_time(
              :string,
              """
              The scheduled start time of the trip in HH:MM:SS format.
              """,
              example: "16:07:00"
            )

            revenue(
              :string,
              """
              Whether this stop event is for a revenue trip:
              - `REVENUE` - A revenue trip
              - `NON_REVENUE` - A non-revenue trip
              """,
              enum: ["REVENUE", "NON_REVENUE"],
              example: "REVENUE"
            )

            stop_id(
              :string,
              """
              The stop ID where the event occurred.
              """,
              example: "2231"
            )

            current_stop_sequence(
              :integer,
              """
              The stop sequence number along the trip. Increases monotonically but values need not be consecutive.
              """,
              example: 1
            )

            arrived(
              [:integer, :null],
              """
              When the vehicle arrived at the stop, as seconds since Unix epoch (UTC). `null` if the first stop on the trip.
              """,
              example: 1771966486,
              "x-nullable": true
            )

            departed(
              [:integer, :null],
              """
              When the vehicle departed from the stop, as seconds since Unix epoch (UTC). `null` if the last stop on the trip or if the vehicle has not yet departed.
              """,
              example: 1771967246,
              "x-nullable": true
            )
          end

          relationship(:trip)
          relationship(:stop)
          relationship(:route)
          relationship(:vehicle)
        end,
      StopEvents: page(:StopEventResource),
      StopEvent: single(:StopEventResource)
    }
  end
end
