defmodule ApiWeb.SwaggerHelpers do
  @moduledoc """
  Collect commonly used parameters for the Swagger documentation generation
  using PhoenixSwagger.
  https://github.com/xerions/phoenix_swagger
  """
  alias PhoenixSwagger.{JsonApi, Path, Schema}

  @sort_types ~w(ascending descending)s

  def comma_separated_list, do: ~S|**MUST** be a comma-separated (U+002C COMMA, ",") list|

  def common_index_parameters(path_object, module, name \\ nil, include \\ nil)
      when is_atom(module) do
    sort_pairs = sort_pairs(module)

    path_object
    |> Path.parameter(
      "page[offset]",
      :query,
      :integer,
      "Offset (0-based) of first element in the page",
      minimum: 0
    )
    |> Path.parameter(
      "page[limit]",
      :query,
      :integer,
      "Max number of elements to return",
      minimum: 1
    )
    |> sort_parameter(sort_pairs, include)
    |> fields_param(name)
  end

  def common_show_parameters(path_object, name) do
    fields_param(path_object, name)
  end

  def direction_id_attribute(schema) do
    JsonApi.attribute(
      schema,
      :direction_id,
      direction_id_schema(),
      """
      Direction in which trip is traveling: `0` or `1`.

      #{direction_id_description()}
      """
    )
  end

  def direction_id_description do
    """
    The meaning of `direction_id` varies based on the route. You can programmatically get the direction names from \
    `/routes` `/data/{index}/attributes/direction_names` or `/routes/{id}` `/data/attributes/direction_names`.
    """
  end

  def direction_id_schema, do: %Schema{type: :integer, enum: [0, 1]}

  @spec occupancy_status_description() :: String.t()
  def occupancy_status_description do
    """
    The degree of passenger occupancy for the vehicle. See [GTFS-realtime OccupancyStatus](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-vehiclestopstatus).

    | _**Value**_                    | _**Description**_                                                                                   |
    |--------------------------------|-----------------------------------------------------------------------------------------------------|
    | **MANY_SEATS_AVAILABLE**       | Not crowded: the vehicle has a large percentage of seats available. |
    | **FEW_SEATS_AVAILABLE**        | Some crowding: the vehicle has a small percentage of seats available. |
    | **STANDING_ROOM_ONLY**         | Standing room only: the vehicle can currently accommodate only standing passengers. |
    | **CRUSHED_STANDING_ROOM_ONLY** | Crushed standing room: the vehicle can currently accommodate only standing passengers and has limited space for them. |
    | **FULL**                       | Crowded: the vehicle is considered full by most measures, but may still be allowing passengers to board. |
    | **NOT_ACCEPTING_PASSENGERS**   | Not accepting passengers: the vehicle is not accepting passengers, the vehicle or carriage usually accepts passengers for boarding. |
    | **NO_DATA_AVAILABLE**          | No data available: the vehicle doesn't have any occupancy data available at that time. |

    """
  end

  @spec carriages_description() :: String.t()
  def carriages_description do
    """
    Carriage-level crowding details. See [GTFS-realtime multi_carriage_details](https://gtfs.org/documentation/realtime/reference/#message-carriagedetails).
    """
  end

  def carriages_schema,
    do: %Schema{
      type: :array,
      minLength: 0,
      items: %{
        type: :object,
        properties: %{
          label: %Schema{
            type: :string,
            description: "Carriage-specific label, used as an identifier"
          },
          occupancy_status: %Schema{
            type: :string,
            description: occupancy_status_description(),
            enum: [
              "EMPTY",
              "MANY_SEATS_AVAILABLE",
              "FEW_SEATS_AVAILABLE",
              "STANDING_ROOM_ONLY",
              "CRUSHED_STANDING_ROOM_ONLY",
              "FULL",
              "NOT_ACCEPTING_PASSENGERS",
              "NO_DATA_AVAILABLE",
              "NOT_BOARDABLE"
            ]
          },
          occupancy_percentage: %Schema{
            type: :integer,
            description: "Percentage of vehicle occupied, calculated via weight average"
          }
        }
      }
    }

  def include_parameters(path_object, includes, options \\ []) do
    Path.parameter(path_object, :include, :query, :string, """
    Relationships to include.

    #{Enum.map_join(includes, "\n", fn include -> "* `#{include}`" end)}

    The value of the include parameter #{comma_separated_list()} of relationship paths. A relationship path is a \
    dot-separated (U+002E FULL-STOP, ".") list of relationship names. \
    [JSONAPI "include" behavior](http://jsonapi.org/format/#fetching-includes)

    #{options[:description]}
    """)
  end

  def filter_param(path_object, name, opts \\ [])

  def filter_param(path_object, :route_type, opts) do
    Path.parameter(
      path_object,
      "filter[route_type]",
      :query,
      :string,
      """
      Filter by route_type: https://gtfs.org/documentation/schedule/reference/#routestxt.

      Multiple `route_type` #{comma_separated_list()}.

      #{opts[:desc]}
      """,
      enum: ["0", "1", "2", "3", "4"]
    )
  end

  def filter_param(path_object, :direction_id, opts) do
    Path.parameter(
      path_object,
      "filter[direction_id]",
      :query,
      :string,
      """
      Filter by direction of travel along the route. Must be used in conjuction with `filter[route]` to apply.

      #{direction_id_description()}

      #{opts[:desc]}
      """,
      enum: ["0", "1"]
    )
  end

  def filter_param(path_object, :position, opts) do
    desc =
      Enum.join(
        [opts[:description], "Latitude/Longitude must be both present or both absent."],
        " "
      )

    path_object
    |> Path.parameter("filter[latitude]", :query, :string, desc)
    |> Path.parameter("filter[longitude]", :query, :string, desc)
  end

  def filter_param(path_object, :radius, opts) do
    parts = [
      opts[:description],
      "Radius accepts a floating point number, and the default is 0.01.  For example, if you query for:",
      "latitude: 42, ",
      "longitude: -71, ",
      "radius: 0.05",
      "then you will filter between latitudes 41.95 and 42.05, and longitudes -70.95 and -71.05."
    ]

    desc = Enum.join(parts, " ")
    Path.parameter(path_object, "filter[radius]", :query, :string, desc, format: :date)
  end

  def filter_param(path_object, :date, opts) do
    parts = [
      opts[:description],
      "The active date is the service date.",
      "Trips that begin between midnight and 3am are considered part of the previous service day.",
      "The format is ISO8601 with the template of YYYY-MM-DD."
    ]

    desc = Enum.join(parts, " ")
    Path.parameter(path_object, "filter[date]", :query, :string, desc, format: :date)
  end

  def filter_param(path_object, :time, opts) do
    parts = [
      opts[:description],
      "The time format is HH:MM."
    ]

    desc = Enum.join(parts, " ")
    name = opts[:name] || :time
    Path.parameter(path_object, "filter[#{name}]", :query, :string, desc, format: :time)
  end

  def filter_param(path_object, :stop_id, opts) do
    desc = opts[:desc] || ""

    desc =
      if opts[:includes_children] do
        "Parent station IDs are treated as though their child stops were also included. #{desc}"
      else
        desc
      end

    clean_opts = Keyword.take(opts, [:type, :required, :name, :in, :desc, :description])
    filter_param(path_object, :id, Keyword.merge(clean_opts, desc: desc, name: :stop))
  end

  def filter_param(path_object, :id, opts) do
    name = Keyword.fetch!(opts, :name)
    json_pointer = "`/data/{index}/relationships/#{name}/data/id`"

    Path.parameter(
      path_object,
      "filter[#{name}]",
      :query,
      :string,
      """
      Filter by #{json_pointer}.

      Multiple IDs #{comma_separated_list()}.

      #{opts[:desc]}
      """,
      Keyword.drop(opts, [:desc, :name])
    )
  end

  def filter_param(path_object, :canonical, opts) do
    Path.parameter(
      path_object,
      "filter[canonical]",
      :query,
      :boolean,
      """
      Filter by canonical

      true: Route pattern should be considered canonical for this route in this direction. If branching regularly occurs, this route-direction may have more than one canonical pattern.
      false: Route pattern should be not considered canonical for this route in this direction.

      #{opts[:desc]}
      """
    )
  end

  def filter_param(path_object, :revenue, opts) do
    Path.parameter(
      path_object,
      "filter[revenue]",
      :query,
      :string,
      """
      #{opts[:desc]}
      Revenue status indicates whether or not the vehicle is accepting passengers.
      When filter is not included, the default behavior is to filter by `revenue=REVENUE`.

      Multiple `revenue` types #{comma_separated_list()}.
      """,
      enum: ["NON_REVENUE", "REVENUE", "NON_REVENUE,REVENUE"]
    )
  end

  def page(resource) do
    resource
    |> JsonApi.page()
    |> (fn schema -> %{schema | "properties" => Map.delete(schema["properties"], "meta")} end).()
  end

  @doc """
  returns the path of the controller and its :index or :show action
  with the properly formatted id path parameter. The {id} is escaped by a simple
  call to `alert_path(ApiWeb.Endpoint, :show, "{id}")`, and does not render
  correctly in the json
  """
  def path(controller, action) do
    controller
    |> path_fn
    |> call_path(action)
  end

  def route_type_description do
    """
    | Value | Name          | Example    |
    |-------|---------------|------------|
    | `0`   | Light Rail    | Green Line |
    | `1`   | Heavy Rail    | Red Line   |
    | `2`   | Commuter Rail |            |
    | `3`   | Bus           |            |
    | `4`   | Ferry         |            |
    """
  end

  defp path_fn(module) do
    Code.ensure_loaded!(ApiWeb.Router.Helpers)

    short_name =
      module
      |> to_string
      |> String.split(".")
      |> List.last()
      |> String.replace_suffix("Controller", "")
      |> String.downcase()

    String.to_existing_atom("#{short_name}_path")
  end

  defp attribute_to_json_pointer("id"), do: "/data/{index}/id"
  defp attribute_to_json_pointer(attribute), do: "/data/{index}/attributes/#{attribute}"

  defp attributes(module) do
    for {_, %{"properties" => %{"attributes" => %{"properties" => properties}}}} <-
          module.swagger_definitions(),
        {attribute, _} <- properties,
        do: attribute
  end

  defp call_path(path_fn, :index),
    do: apply(ApiWeb.Router.Helpers, path_fn, [%URI{path: ""}, :index])

  defp call_path(path_fn, :show) do
    "#{call_path(path_fn, :index)}/{id}"
  end

  defp direction_to_prefix("ascending"), do: ""
  defp direction_to_prefix("descending"), do: "-"

  defp fields_param(path_object, name) do
    case name do
      nil ->
        path_object

      name ->
        Path.parameter(
          path_object,
          "fields[#{name}]",
          :query,
          :string,
          """
          Fields to include with the response. Multiple fields #{comma_separated_list()}.

          Note that fields can also be selected for included data types: see the [V3 API Best Practices](https://www.mbta.com/developers/v3-api/best-practices) for an example.
          """
        )
    end
  end

  defp sort_enum(sort_pairs), do: Enum.map(sort_pairs, &sort_pair_to_sort/1)

  defp sort_pairs(module) do
    for attribute <- attributes(module),
        direction <- @sort_types,
        do: {attribute, direction}
  end

  defp sort_pair_to_sort({attribute, direction}),
    do: "#{direction_to_prefix(direction)}#{attribute}"

  defp sort_parameter(path_object, sort_pairs, :include_distance),
    do:
      format_sort_parameter(
        path_object,
        sort_pairs,
        """
        Results can be [sorted](http://jsonapi.org/format/#fetching-sorting) by the id or any `/data/{index}/attributes` \
        key. Sorting by distance requires `filter[latitude]` and `filter[longitude]` to be set. Assumes ascending; may be \
        prefixed with '-' for descending.

        #{sort_table(sort_pairs)} #{distance_sort_options()}
        """,
        for(sort_type <- @sort_types, do: {"distance", sort_type})
      )

  defp sort_parameter(path_object, sort_pairs, :include_time),
    do:
      format_sort_parameter(
        path_object,
        sort_pairs,
        """
        Results can be [sorted](http://jsonapi.org/format/#fetching-sorting) by the id or any `/data/{index}/attributes` \
        key.

        #{sort_table(sort_pairs)} #{time_sort_options()}
        """,
        for(sort_type <- @sort_types, do: {"time", sort_type})
      )

  defp sort_parameter(path_object, sort_pairs, _),
    do:
      format_sort_parameter(
        path_object,
        sort_pairs,
        """
        Results can be [sorted](http://jsonapi.org/format/#fetching-sorting) by the id or any `/data/{index}/attributes` \
        key. Assumes ascending; may be prefixed with '-' for descending

        #{sort_table(sort_pairs)}
        """
      )

  defp format_sort_parameter(path_object, sort_pairs, description, extra_options \\ []),
    do:
      Path.parameter(
        path_object,
        :sort,
        :query,
        :string,
        description,
        enum: sort_enum(sort_pairs ++ extra_options)
      )

  defp distance_sort_options do
    for sort_type <- @sort_types do
      """
      | Distance to \
      (`#{attribute_to_json_pointer("latitude")}`, `#{attribute_to_json_pointer("longitude")}`) \
      | #{sort_type} | `#{sort_pair_to_sort({"distance", sort_type})}` |
      """
    end
  end

  defp time_sort_options do
    for sort_type <- @sort_types do
      """
      | `/data/{index}/attributes/arrival_time` if present, otherwise `/data/{index}/attributes/departure_time` \
      | #{sort_type} | `#{sort_pair_to_sort({"time", sort_type})}` |
      """
    end
  end

  defp sort_row({attribute, direction} = pair) do
    "| `#{attribute_to_json_pointer(attribute)}` | #{direction} | `#{sort_pair_to_sort(pair)}` |"
  end

  defp sort_rows(sort_pairs), do: Enum.map_join(sort_pairs, "\n", &sort_row/1)

  defp sort_table(sort_pairs) do
    """
    | JSON pointer | Direction | `sort`     |
    |--------------|-----------|------------|
    #{sort_rows(sort_pairs)}
    """
  end
end
