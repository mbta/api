defmodule ApiWeb.ServiceController do
  @moduledoc """
  Controller for Services. Filterable by:

  * id (multiple)
  """
  use ApiWeb.Web, :api_controller
  alias State.Service

  plug(ApiWeb.Plugs.ValidateDate)

  @filters ~w(id route)s
  @pagination_opts ~w(offset limit order_by)a

  def state_module, do: State.Service

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    List of services. Service represents the days of the week, as well as extra days, that a trip \
    is valid.
    """)

    common_index_parameters(__MODULE__, :service)

    parameter(
      "filter[id]",
      :query,
      :string,
      "Filter by multiple IDs. #{comma_separated_list()}.",
      example: "1,2"
    )

    parameter(
      "filter[route]",
      :query,
      :string,
      "Filter by route. Multiple `route` #{comma_separated_list()}."
    )

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Services))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    case Params.filter_params(params, @filters, conn) do
      {:ok, filters} when map_size(filters) > 0 ->
        filters
        |> apply_filters()
        |> State.all(Params.filter_opts(params, @pagination_opts, conn))

      {:error, _, _} = error ->
        error

      _ ->
        {:error, :filter_required}
    end
  end

  defp apply_filters(%{"id" => id}) do
    id
    |> Params.split_on_comma()
    |> Service.by_ids()
  end

  defp apply_filters(%{"route" => route}) do
    route
    |> Params.split_on_comma()
    |> Service.by_route_ids()
  end

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Single service, which represents the days of the week, as well as extra days, that a trip \
    is valid.
    """)

    parameter(:id, :path, :string, "Unique identifier for a service")
    common_show_parameters(:service)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Service))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(406, "Not Acceptable", Schema.ref(:NotAcceptable))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(_conn, %{"id" => id}) do
    Service.by_id(id)
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      ServiceResource:
        resource do
          description("Service represents a set of dates on which trips run.")

          attributes do
            start_date(
              :string,
              "Earliest date which is valid for this service. Format is ISO8601.",
              format: :date,
              example: "2018-11-19"
            )

            end_date(
              :string,
              "Latest date which is valid for this service. Format is ISO8601.",
              format: :date,
              example: "2018-12-24"
            )

            description(
              :string,
              "Human-readable description of the service, as it should appear on public-facing websites and applications.",
              "x-nullable": true,
              example: "Weekday schedule (no school)"
            )

            schedule_name(
              :string,
              "Description of when the `service_id` is in effect.",
              "x-nullable": true,
              example: "Weekday (no school)"
            )

            schedule_type(
              :string,
              """
              Description of the schedule type the service_id can be applied.
              For example, on a holiday, the schedule_type value may be "Saturday" or "Sunday".
              Current valid values are "Weekday", "Saturday", "Sunday", or "Other"
              """,
              "x-nullable": true,
              example: "Sunday"
            )

            schedule_typicality(
              :integer,
              """
              Describes how well this schedule represents typical service for the listed `schedule_type`

              | Value | Description                                                                 |
              |-------|-----------------------------------------------------------------------------|
              | `0`   | Not defined.                                                                |
              | `1`   | Typical service with perhaps minor modifications                            |
              | `2`   | Extra service supplements typical schedules                                 |
              | `3`   | Reduced holiday service is provided by typical Saturday or Sunday schedule  |
              | `4`   | Major changes in service due to a planned disruption, such as construction  |
              | `5`   | Major reductions in service for weather events or other atypical situations |
              """,
              enum: Enum.to_list(0..5),
              example: 1
            )

            rating_start_date(
              :string,
              "Earliest date which is a part of the rating (season) which contains this service. Format is ISO8601.",
              "x-nullable": true,
              format: :date,
              example: "2018-12-22"
            )

            rating_end_date(
              :string,
              "Latest date which is a part of the rating (season) which contains this service. Format is ISO8601.",
              "x-nullable": true,
              format: :date,
              example: "2019-03-14"
            )

            rating_description(
              :string,
              "Human-readable description of the rating (season), as it should appear on public-facing websites and applications.",
              "x-nullable": true,
              example: "Winter"
            )
          end

          array_attribute(
            :added_dates,
            :date,
            "Aditional dates when the service is valid. Format is ISO8601.",
            "2018-11-21"
          )

          array_attribute(
            :added_dates_notes,
            :string,
            "Extra information about additional dates (e.g. holiday name)",
            "New Year Day"
          )

          array_attribute(
            :removed_dates,
            :date,
            "Exceptional dates when the service is not valid. Format is ISO8601.",
            "2018-12-17"
          )

          array_attribute(
            :removed_dates_notes,
            :string,
            "Extra information about exceptional dates (e.g. holiday name)",
            "New Year Day"
          )

          valid_dates_attribute()
        end,
      Services: page(:ServiceResource),
      Service: single(:ServiceResource)
    }
  end

  defp array_attribute(schema, property, type, description, example) do
    nested = Schema.array(:string)
    nested = put_in(nested.items.description, description)
    nested = put_in(nested.items.format, type)
    nested = put_in(nested.items.example, example)
    put_in(schema.properties.attributes.properties[property], nested)
  end

  defp valid_dates_attribute(schema) do
    nested = Schema.array(:number)

    nested =
      put_in(nested.items.description, """
        Day of week. From Monday as 1 to Sunday as 7.
      """)

    nested = put_in(nested.items.example, "1")
    put_in(schema.properties.attributes.properties[:valid_days], nested)
  end
end
