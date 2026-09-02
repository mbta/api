defmodule ApiWeb.TransferController do
  @moduledoc """
  Controller for Transfers. Filterable by:

  * from_trip (multiple)
  """
  use ApiWeb.Web, :api_controller

  @filters ~w(from_trip)s
  @pagination_opts ~w(offset limit)a
  @includes ~w(from_trip to_trip from_stop to_stop)

  def state_module, do: State.Transfer

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    **NOTE:** `filter[from_trip]` **MUST** be present for any transfers to be returned.

    List of transfers. Transfer specifies additional rules and overrides for a transfer between trips, routes, and/or stops.

    ## Transfers from a certain trip

    `/transfers?filter[from_trip]=TRIP_ID`

    ## Transfers from a set of trips

    `/transfers?filter[from_trip]=TRIP_ID1,TRIP_ID2,TRIP_ID3`
    """)

    common_index_parameters(__MODULE__, :transfer)

    include_parameters()

    parameter(
      "filter[from_trip]",
      :query,
      :string,
      "Filter by trip ID. Multiple trips #{comma_separated_list()}."
    )

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Transfer))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    with :ok <- Params.validate_includes(params, @includes, conn) do
      case Params.filter_params(params, @filters, conn) do
        {:ok, filters} when map_size(filters) > 0 ->
          filters
          |> format_filters()
          |> State.Transfer.filter_by()
          |> State.all(Params.filter_opts(params, @pagination_opts, conn))

        {:error, _, _} = error ->
          error

        _ ->
          {:error, :filter_required}
      end
    else
      {:error, _, _} = error -> error
    end
  end

  defp format_filters(filters) do
    filters
    |> Enum.flat_map(&do_format_filter/1)
    |> Enum.into(%{})
  end

  defp do_format_filter({"from_trip", trip_string}) do
    case Params.split_on_comma(trip_string) do
      [] ->
        []

      trip_ids ->
        %{from_trip_ids: trip_ids}
    end
  end

  defp do_format_filter(_), do: []

  # No show action here
  def show_data(_conn, _params), do: []

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      TransferResource:
        resource do
          description("Transfer specifies additional rules and overrides for a transfer.")

          attributes do
            min_transfer_time(
              :integer,
              "Sum of `min_walk_time` and `suggested_buffer_time`, in seconds.",
              "x-nullable": true,
              example: 9
            )

            min_walk_time(
              :integer,
              "Experimental. Minimum time required to travel by foot from `from_stop_id` to `to_stop_id`, in seconds.",
              "x-nullable": true,
              example: 4
            )

            min_wheelchair_time(
              :integer,
              "Experimental. Minimum time required to travel by wheelchair `from_stop_id` to `to_stop_id`, in seconds. If the transfer is not wheelchair accessible, this field will be blank.",
              "x-nullable": true,
              example: 7
            )

            suggested_buffer_time(
              :integer,
              "Experimental. Recommended buffer time to allow to make a successful transfer between two services, in seconds. This is also partly based on the significance of missing the transfer (due to service frequency).",
              "x-nullable": true,
              example: 5
            )

            transfer_type(
              :integer,
              """
              Indicates the type of connection for the specified (`from_stop_id`, `to_stop_id`) pair.

              | Value | Description |
              |-------|-------------|
              | `0`   | Recommended transfer point between route |
              | `1`   | Timed transfer point between two routes. The departing vehicle is expected to wait for the arriving one and leave sufficient time for a rider to transfer between routes. |
              | `2`   | Transfer requires a minimum amount of time between arrival and departure to ensure a connection. The time required to transfer is specified by `min_transfer_time`. |
              | `3`   | Transfers are not possible between routes at the location. |
              | `4`   | Passengers can transfer from one trip to another by staying onboard the same vehicle (an "in-seat transfer"). |
              | `5`   | In-seat transfers are not allowed between sequential trips. The passenger must alight from the vehicle and re-board. |
              """,
              enum: Enum.to_list(0..5),
              example: 1
            )

            wheelchair_transfer(
              :integer,
              """
              Experimental. Identifies whether a transfer is accessible to customers using a wheelchair.

              | Value | Description |
              |-------|-------------|
              | `0`   | No accessibility information for the transfer |
              | `1`   | Transfer is wheelchair accessible |
              | `2`   | Not accessible to persons in wheelchairs |
              """,
              enum: Enum.to_list(0..2),
              example: 0
            )
          end

          relationship(:from_stop)
          relationship(:to_stop)
          relationship(:from_trip)
          relationship(:to_trip)
        end,
      Transfer: page(:TransferResource)
    }
  end

  defp include_parameters(schema) do
    ApiWeb.SwaggerHelpers.include_parameters(
      schema,
      @includes,
      description: """
      | include     | Description |
      |-------------|-------------|
      | `from_trip` | The trip where a connection between routes begins |
      | `to_trip`   | The trip where a connection between routes ends |
      | `from_stop` | The stop or station where a connection between routes begins |
      | `to_stop`   | The stop or station where a connection between routes ends |
      """
    )
  end
end
