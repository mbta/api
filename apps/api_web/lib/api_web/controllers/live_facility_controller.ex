defmodule ApiWeb.LiveFacilityController do
  use ApiWeb.Web, :api_controller
  import ApiWeb.Params

  @filters ~w(id)
  @pagination_opts ~w(offset limit order_by)a

  def state_module, do: State.Facility.Parking

  swagger_path :index do
    get(path("live_facility", :index))

    description("""
    Live Facility Data

    #{swagger_path_description("/data")}
    """)

    common_index_parameters(__MODULE__)
    filter_param(:id)

    parameter(
      "filter[id]",
      :query,
      :string,
      "Filter by parking facility id."
    )

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:LiveFacility))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(_conn, params) do
    case Params.filter_params(params, @filters) do
      %{"id" => ids} ->
        ids
        |> split_on_comma
        |> State.Facility.Parking.by_facility_ids()
        |> Enum.group_by(& &1.facility_id)
        |> Enum.map(fn {facilty_id, properties} ->
          %{
            facility_id: facilty_id,
            properties: properties,
            updated_at: updated_at(properties)
          }
        end)
        |> State.all(Params.filter_opts(params, @pagination_opts))

      _ ->
        {:error, :filter_required}
    end
  end

  swagger_path :show do
    get(path("live_facility", :show))

    description("""
    List live parking data for specific parking facility

    #{swagger_path_description("/data/{index}")}
    """)

    parameter(:id, :path, :string, "Unique identifier for facility")

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:LiveFacility))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(_conn, %{"id" => facility_id}) do
    case State.Facility.Parking.by_facility_id(facility_id) do
      [] ->
        nil

      properties ->
        %{
          facility_id: facility_id,
          properties: properties,
          updated_at: updated_at(properties)
        }
    end
  end

  def updated_at(properties) do
    properties
    |> Enum.map(&DateTime.to_iso8601(&1.updated_at))
    |> Enum.max()
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      LiveFacilityResource:
        resource do
          description(swagger_path_description("*"))

          attributes do
            updated_at(
              %Schema{type: :string, format: :"date-time"},
              "Time of last update",
              example: "2017-08-14T15:38:58-04:00"
            )

            properties(
              %Schema{
                type: :array,
                items: Schema.ref(:FacilityProperty)
              },
              "A list of name/value pairs that apply to the facility. See [MBTA's facility documentation](https://www.mbta.com/developers/gtfs/f#facilities_properties_definitions) for more information on the possible names and values."
            )
          end
        end,
      LiveFacility: single(:LiveFacilityResource),
      LiveFacilities: page(:LiveFacilityResource)
    }
  end

  defp swagger_path_description(_parent_pointer) do
    """
    Live data about a given facility.
    """
  end
end
