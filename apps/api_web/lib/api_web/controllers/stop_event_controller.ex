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
  @includes ~w(trip stop route vehicle schedule)
  @pagination_opts [:offset, :limit, :order_by]
  @description """
  ## Queries against this path do not yet return results

  Stop events represent the actual arrival and departure times of vehicles at stops along their trips.

  Stop events are unique to the start_date, trip_id, route_id, vehicle_id, and stop_sequence.

  To return a list of stop events, **provide at least 1 filter parameter**; requests without filters will return an error.
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

    filter_param(:direction_id, desc: "Must be used in conjunction with another filter.")

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:StopEvents))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
    tag("StopEvents 🧪")
    summary("experimental")
  end

  def index_data(conn, params) do
    with :ok <- Params.validate_includes(params, @includes, conn),
         {:ok, filtered} <- Params.filter_params(params, @filters, conn) do
      formatted_filters = format_filters(filtered)

      cond do
        map_size(formatted_filters) == 0 ->
          {:error, :filter_required}

        Map.keys(formatted_filters) == [:direction_id] ->
          {:error, :only_direction_id}

        true ->
          formatted_filters
          |> StopEvent.filter_by()
          |> State.all(pagination_opts(params, conn))
      end
    else
      {:error, _, _} = error -> error
    end
  end

  @spec format_filters(%{optional(String.t()) => String.t()}) :: StopEvent.filters()
  defp format_filters(filters) do
    Enum.reduce(filters, %{}, fn
      {"trip", trip_ids}, acc ->
        Map.put(acc, :trip_ids, Params.split_on_comma(trip_ids))

      {"stop", stop_ids}, acc ->
        Map.put(acc, :stop_ids, Params.split_on_comma(stop_ids))

      {"route", route_ids}, acc ->
        Map.put(acc, :route_ids, Params.split_on_comma(route_ids))

      {"vehicle", vehicle_ids}, acc ->
        Map.put(acc, :vehicle_ids, Params.split_on_comma(vehicle_ids))

      {"direction_id", direction_id}, acc ->
        Map.put(acc, :direction_id, Params.direction_id(%{"direction_id" => direction_id}))

      _, acc ->
        acc
    end)
  end

  defp pagination_opts(params, conn) do
    opts =
      params
      |> Params.filter_opts(@pagination_opts, conn)

    if is_list(opts) do
      Keyword.put_new(opts, :order_by, {:arrived, :desc})
    else
      opts
      |> Map.to_list()
      |> Keyword.put_new(:order_by, {:arrived, :desc})
    end
  end

  swagger_path :show do
    get(path("stop_event", :show))

    description("""
    Show a particular stop event by its composite ID.

    #{@description}
    """)

    parameter(
      :id,
      :path,
      :string,
      "Unique identifier for stop event (trip_id-route_id-vehicle_id-stop_sequence)"
    )

    include_parameters()

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:StopEvent))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
    tag("StopEvents 🧪")
    summary("experimental")
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
      | `schedule` | The scheduled arrival/departure for this stop event. |

      Note that the included entities may appear in past events but no longer in realtime feeds, so included relationships may be empty.
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

            stop_sequence(
              :integer,
              """
              The stop sequence number along the trip. Increases monotonically but values need not be consecutive.
              """,
              example: 1
            )

            arrived(
              nullable(%Schema{type: :string, format: :"date-time"}, true),
              """
              When the vehicle arrived at the stop. Format is ISO8601/RFC 3339. `null` if the first stop on the trip.
              """,
              example: "2026-03-13T10:30:00-04:00"
            )

            departed(
              nullable(%Schema{type: :string, format: :"date-time"}, true),
              """
              When the vehicle departed from the stop. Format is ISO8601/RFC 3339. `null` if the last stop on the trip or if the vehicle has not yet departed.
              """,
              example: "2026-03-13T10:43:00-04:00"
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
