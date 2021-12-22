defmodule ApiWeb.LiveFacilityController do
  use ApiWeb.Web, :api_controller
  import ApiWeb.Params

  plug(:ensure_path_matches_version)

  @filters ~w(id)
  @pagination_opts ~w(offset limit order_by)a
  @includes ~w(facility)

  def state_module, do: State.Facility.Parking

  swagger_path :index do
    get(path("live_facility", :index))

    description("""
    Live Facility Data

    #{swagger_path_description("/data")}
    """)

    common_index_parameters(__MODULE__)
    include_parameters(@includes)

    parameter(
      "filter[id]",
      :query,
      :string,
      "Filter by multiple parking facility ids. #{comma_separated_list()}."
    )

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:LiveFacility))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  defp ensure_path_matches_version(conn, _) do
    if String.starts_with?(conn.request_path, "/live_facilities") or
         conn.assigns.api_version < "2019-07-01" do
      conn
    else
      conn
      |> put_status(:not_found)
      |> put_view(ApiWeb.ErrorView)
      |> render("404.json-api", [])
      |> halt()
    end
  end

  def index_data(conn, params) do
    with :ok <- Params.validate_includes(params, @includes, conn),
         {:ok, filtered} <- Params.filter_params(params, @filters, conn) do
      case filtered do
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
          |> State.all(Params.filter_opts(params, @pagination_opts, conn))

        _ ->
          {:error, :filter_required}
      end
    else
      {:error, _, _} = error -> error
    end
  end

  swagger_path :show do
    get(path("live_facility", :show))

    description("""
    List live parking data for specific parking facility

    #{swagger_path_description("/data/{index}")}
    """)

    parameter(:id, :path, :string, "Unique identifier for facility")
    include_parameters(@includes)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:LiveFacility))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(406, "Not Acceptable", Schema.ref(:NotAcceptable))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(conn, %{"id" => facility_id} = params) do
    with :ok <- Params.validate_includes(params, @includes, conn),
         [_ | _] = properties <- State.Facility.Parking.by_facility_id(facility_id) do
      %{
        facility_id: facility_id,
        properties: properties,
        updated_at: updated_at(properties)
      }
    else
      {:error, _, _} = error -> error
      [] -> nil
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
