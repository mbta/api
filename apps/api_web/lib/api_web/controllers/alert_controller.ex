defmodule ApiWeb.AlertController do
  use ApiWeb.Web, :api_controller
  alias State.{Alert, Alert.InformedEntityActivity}

  @activity_filters ~w(activity)
  @non_activity_filters ~w(id direction_id facility route route_type stop trip banner datetime lifecycle severity)
  @filters @activity_filters ++ @non_activity_filters
  @pagination_opts ~w(offset limit order_by)a
  @includes ~w(stops routes trips facilities)

  def state_module, do: State.Alert

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    List active and upcoming system alerts

    #{swagger_path_description("/data/{index}")}

    ## Activities

    Alerts are by default filtered to those where \
    `/data/{index}/attributes/informed_entity/{informed_entity_index}/activities/{activity_index}` in one of \
    #{InformedEntityActivity.default_activities()}, as these cover most riders.  If you want all alerts without \
    filtering by activity, you should use the special value `"ALL"`: `filter[activity]=ALL`.

    ### Accessibility

    #{filter_activity_accessibility()}
    """)

    common_index_parameters(__MODULE__, :alert)
    include_parameters(@includes)

    parameter(
      "filter[activity]",
      :query,
      :string,
      """
      Filter to alerts for only those activities \
      (`/data/{index}/attributes/informed_entity/activities/{activity_index}`) matching.  Multiple activities
      #{comma_separated_list()}.

      #{typedoc(:activity)}

      ## Special Values

      * If the filter is not given OR it is empty, then defaults to \
      #{InformedEntityActivity.default_activities() |> inspect()}.
      * If the value `"ALL"` is used then all alerts will be returned, not just those with the default \
      activities.

      ## Accessibility

      #{filter_activity_accessibility()}
      """,
      default: InformedEntityActivity.default_activities() |> Enum.join(","),
      example: "BOARD,EXIT"
    )

    filter_param(:route_type)
    filter_param(:direction_id)
    filter_param(:id, name: :route)
    filter_param(:stop_id, includes_children: true)
    filter_param(:id, name: :trip)
    filter_param(:id, name: :facility)

    parameter(
      "filter[id]",
      :query,
      :string,
      "Filter by multiple IDs. Multiple IDs #{comma_separated_list()}.",
      example: "1,2"
    )

    parameter(
      "filter[banner]",
      :query,
      :string,
      """
      When combined with other filters, filters by alerts with or \
      without a banner. **MUST** be "true" or "false".
      """,
      example: "true"
    )

    parameter(
      "filter[datetime]",
      :query,
      :string,
      """
      Filter to alerts that are active at a given time (ISO8601 format).

      Additionally, the string "NOW" can be used to filter to alerts that are currently active.
      """,
      example: "2018-05-09T13:06:00-04:00"
    )

    parameter("filter[lifecycle]", :query, :string, """
    Filters by an alert's lifecycle. #{comma_separated_list()}.
    """)

    parameter("filter[severity]", :query, :string, """
    Filters alerts by list of severities. #{comma_separated_list()}.

    Example: filter[severity]=3,4,10 returns alerts with severity levels 3, 4 and 10.
    """)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Alerts))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    with {:ok, filtered} <- Params.filter_params(params, @filters, conn) do
      filtered
      |> apply_filters(conn.assigns.api_version)
      |> case do
        list when is_list(list) ->
          State.all(list, Params.filter_opts(params, @pagination_opts, conn))

        {:error, _} = error ->
          error
      end
    else
      {:error, _, _} = error -> error
    end
  end

  swagger_path :show do
    get(path(__MODULE__, :show))

    description("""
    Show a particular alert by the alert's id

    #{swagger_path_description("/data")}
    """)

    parameter(:id, :path, :string, "Unique identifier for alert")
    common_show_parameters(:alert)
    include_parameters(@includes)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")

    response(200, "OK", Schema.ref(:Alert))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(404, "Not Found", Schema.ref(:NotFound))
    response(406, "Not Acceptable", Schema.ref(:NotAcceptable))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def show_data(_conn, %{"id" => id}) do
    Alert.by_id(id)
  end

  defp apply_filters(param_list, _api_version) when param_list == %{} do
    # this gets around what should be default filtering where activities
    # without one of the default activities
    State.Alert.all()
  end

  defp apply_filters(param_list, api_version) do
    param_list
    |> build_query()
    |> expand_stops_filter(:stops, api_version)
    |> State.Alert.filter_by()
  rescue
    ArgumentError ->
      {:error, :invalid}
  end

  def build_query(param_list) do
    Enum.reduce(param_list, %{}, &do_build_query/2)
  end

  defp comma_separated_list_to_list(comma_separated_list) when is_binary(comma_separated_list) do
    comma_separated_list
    |> String.split(",", trim: true)
    |> Stream.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp do_build_query({"severity", value_str}, acc) do
    case Params.integer_values(value_str) do
      [] ->
        acc

      [_ | _] = value ->
        put_in(acc[:severity], value)
    end
  end

  defp do_build_query({"id", value_str}, acc) do
    put_comma_separated_list_in(acc, :ids, value_str)
  end

  defp do_build_query({"route_type", value_str}, acc) do
    case Params.integer_values(value_str) do
      [] ->
        put_in(acc[:route_types], [nil])

      values ->
        put_in(acc[:route_types], values)
    end
  end

  defp do_build_query({"direction_id", value_str}, acc) do
    case Params.integer_values(value_str) do
      [] ->
        put_in(acc[:direction_id], nil)

      [value] ->
        put_in(acc[:direction_id], value)

      _ ->
        acc
    end
  end

  defp do_build_query({"stop", value_str}, acc) do
    put_comma_separated_list_in(acc, :stops, value_str)
  end

  defp do_build_query({"route", value_str}, acc) do
    put_comma_separated_list_in(acc, :routes, value_str)
  end

  defp do_build_query({"activity", ""}, acc) do
    # override the default empty string behavior because we want to treat
    # this as a default, rather than matching alerts with no activities
    put_in(acc[:activities], [])
  end

  defp do_build_query({"activity", value_str}, acc) do
    put_comma_separated_list_in(acc, :activities, value_str)
  end

  defp do_build_query({"facility", value_str}, acc) do
    put_comma_separated_list_in(acc, :facilities, value_str)
  end

  defp do_build_query({"trip", value_str}, acc) do
    put_comma_separated_list_in(acc, :trips, value_str)
  end

  defp do_build_query({"banner", "true"}, acc) do
    Map.put(acc, :banner, true)
  end

  defp do_build_query({"banner", "false"}, acc) do
    Map.put(acc, :banner, false)
  end

  defp do_build_query({"banner", _}, acc) do
    # ignore invalid banner value
    acc
  end

  defp do_build_query({"datetime", "NOW"}, acc) do
    Map.put(acc, :datetime, DateTime.utc_now())
  end

  defp do_build_query({"datetime", iso_dt}, acc) do
    case DateTime.from_iso8601(iso_dt) do
      {:ok, dt, _} -> Map.put(acc, :datetime, dt)
      _ -> acc
    end
  end

  defp do_build_query({"lifecycle", value_str}, acc) do
    put_comma_separated_list_in(acc, :lifecycles, value_str)
  end

  defp put_comma_separated_list_in(acc, key, "") do
    Map.put(acc, key, [nil])
  end

  defp put_comma_separated_list_in(acc, key, value_str) do
    values = comma_separated_list_to_list(value_str)
    Map.put(acc, key, values)
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    cause_enum = Model.Alert.cause_enum()
    effect_enum = Model.Alert.effect_enum()

    %{
      Activity:
        swagger_schema do
          description(typedoc(:activity))
          example("BOARD")
          type(:string)
        end,
      InformedEntity:
        swagger_schema do
          description(typedoc(:informed_entity))

          properties do
            activities(
              %Schema{type: :array, items: Schema.ref(:Activity)},
              typedoc(:activities),
              example: ["BOARD", "EXIT"]
            )

            direction_id(
              nullable(direction_id_schema(), true),
              "`direction_id` of the affected Trip.\n\n" <> direction_id_description(),
              example: 0
            )

            facility(nullable(%Schema{type: :string}, true), "`id` of the affected Facility.",
              example: "405"
            )

            route(nullable(%Schema{type: :string}, true), "`id` of the affected Route.",
              example: "CR-Worcester"
            )

            route_type(
              nullable(%Schema{type: :integer}, true),
              "`type` of the affected Route.\n\n" <> route_type_description(),
              example: 2
            )

            stop(nullable(%Schema{type: :string}, true), "`id` of the affected Stop.",
              example: "Auburndale"
            )

            trip(nullable(%Schema{type: :string}, true), "`id` of the affected Trip.",
              example: "CR-Weekday-Spring-17-517"
            )
          end
        end,
      ActivePeriod:
        swagger_schema do
          description("Start and End dates for active alert")

          property(
            "start",
            :string,
            "Start Date. Format is ISO8601.",
            format: :"date-time",
            example: "2017-08-14T14:54:01-04:00"
          )

          property(
            "end",
            nullable(%Schema{type: :string}, true),
            "End Date. Format is ISO8601.",
            format: :"date-time",
            example: "2017-08-14T14:54:01-04:00"
          )
        end,
      AlertResource:
        resource do
          description(swagger_path_description("*"))

          attributes do
            active_period(
              %Schema{
                items: Schema.ref(:ActivePeriod),
                type: :array
              },
              """
              Date/Time ranges when alert is active. See \
              [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `active_period`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert).
              """
            )

            banner(
              nullable(%Schema{type: :string}, true),
              "Set if alert is meant to be displayed prominently, such as the top of every page.",
              example: "All service suspended due to severe weather"
            )

            cause(
              %Schema{type: :string, enum: cause_enum},
              """
              What is causing the alert.

              #{typedoc(:cause)}
              """,
              example: hd(cause_enum)
            )

            created_at(
              %Schema{type: :string, format: :"date-time"},
              "Date/Time alert created. Format is ISO8601.",
              example: "2017-08-14T14:54:01-04:00"
            )

            description(
              nullable(%Schema{type: :string}, true),
              """
              This plain-text string will be formatted as the body of the alert (or shown on an explicit \
              "expand" request by the user). The information in the description should add to the information \
              of the header. See \
              [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `description_text`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)
              """,
              example: """
              If entering the station, cross Tremont Street to the Boston Common and use Park Street Elevator \
              978 to the Green Line westbound platform. Red Line platform access is available via the elevator \
              beyond the fare gates. If exiting the station, please travel down the Winter Street Concourse \
              toward Downtown Crossing Station, exit through the fare gates, and take Downtown Crossing \
              Elevator 892 to the street level.
              """
            )

            effect(
              %Schema{type: :string, enum: effect_enum},
              """
              The effect of this problem on the affected entity.

              #{typedoc(:effect)}
              """,
              example: hd(effect_enum)
            )

            effect_name(:string, "Name of the alert", example: "Delay")

            header(
              :string,
              """
              This plain-text string will be highlighted, for example in boldface. See \
              [GTFS Realtime `FeedMessage` `FeedEntity` `Alert` `header_text`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)
              """,
              example: """
              Starting 6/3, all weekend Fairmount Line trains will be bused between Morton St. and Readville in both \
              directions due to construction of the new Blue Hill Avenue Station.
              """
            )

            informed_entity(
              %Schema{
                items: Schema.ref(:InformedEntity),
                type: :array
              },
              "Entities affected by this alert."
            )

            lifecycle(:string, typedoc(:lifecycle), example: "Ongoing")

            severity(
              :integer,
              "How severe the alert it from least (`0`) to most (`10`) severe.",
              example: 10,
              maximum: 10,
              minimum: 0
            )

            service_effect(
              :string,
              "Summarizes the service and the impact to that service.",
              example: "Minor Route 216 delay"
            )

            short_header(
              :string,
              "A shortened version of `*/attributes/header`.",
              example: """
              All weekend Fairmount Line trains will be bused between Morton St. & Readville due to \
              construction of Blue Hill Ave Station.
              """
            )

            timeframe(
              nullable(%Schema{type: :string}, true),
              "Summarizes when an alert is in effect.",
              example: "Ongoing"
            )

            updated_at(
              %Schema{type: :string, format: :"date-time"},
              "Date/Time alert last updated. Format is ISO8601.",
              example: "2017-08-14T14:54:01-04:00"
            )

            url(
              nullable(%Schema{type: :string}, true),
              "A URL for extra details, such as outline construction or maintenance plans.",
              example:
                "http://www.mbta.com/uploadedfiles/Documents/Schedules_and_Maps/Commuter_Rail/fairmount.pdf?led=6/3/2017%201:22:09%20AM"
            )
          end

          relationship(:facility)
        end,
      Alerts: page(:AlertResource),
      Alert: single(:AlertResource)
    }
  end

  defp filter_activity_accessibility do
    """
    The default activities cover if boarding, exiting, or riding is generally affected for all riders by the alert. \
    If ONLY wheelchair using riders are affected, such as if a ramp, lift, or safety system for wheelchairs is \
    affected, only the `"USING_WHEELCHAIR"` activity will be set. To cover wheelchair using rider, filter on the \
    defaults and `"USING_WHEELCHAIR"`: \
    `filter[activity]=#{["USING_WHEELCHAIR" | InformedEntityActivity.default_activities()] |> Enum.join(",")}`.

    Similarly for riders with limited mobility that need escalators, `"USING_ESCALATOR"` should be added to the \
    defaults: \
    `filter[activity]=#{["USING_ESCALATOR" | InformedEntityActivity.default_activities()] |> Enum.join(",")}`.
    """
  end

  defp swagger_path_description(parent_pointer) do
    """
    An effect (enumerated in `#{parent_pointer}/attributes/effect` and human-readable in \
    `#{parent_pointer}/attributes/service_effect`) on a provided service (facility, route, route type, stop and/or \
    trip in `/#{parent_pointer}/attributes/informed_entity`) described by a banner \
    (`#{parent_pointer}/attributes/banner`), short header (`#{parent_pointer}/attributes/short_header`), header \
    `#{parent_pointer}/attributes/header`, and description (`#{parent_pointer}/attributes/description`) that is active \
    for one or more periods (`#{parent_pointer}/attributes/active_period`) caused by a cause \
    (`#{parent_pointer}/attribute/cause`) that somewhere in its lifecycle (enumerated in \
    `#{parent_pointer}/attributes/lifecycle` and human-readable in `#{parent_pointer}/attributes/timeframe`).

    See [GTFS Realtime `FeedMessage` `FeedEntity` `Alert`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-alert)

    ## Descriptions

    There are 5 descriptive attributes.

    | JSON pointer                                | Usage                                                                           |
    |---------------------------------------------|---------------------------------------------------------------------------------|
    | `#{parent_pointer}/attributes/banner`       | Display as alert across application/website                                     |
    | `#{parent_pointer}/attributes/short_header` | When `#{parent_pointer}/attributes/header` is too long to display               |
    | `#{parent_pointer}/attributes/header`       | Used before showing and prepended to `#{parent_pointer}/attributes/description` |
    | `#{parent_pointer}/attributes/description`  | Used when user asks to expand alert.                                            |

    ## Effect

    | JSON pointer                                  |                |
    |-----------------------------------------------|----------------|
    | `#{parent_pointer}/attributes/effect`         | Enumerated     |
    | `#{parent_pointer}/attributes/service_effect` | Human-readable |

    ## Timeline

    There are 3 timeline related attributes

    | JSON pointer                                 | Description                                                                              |
    |----------------------------------------------|------------------------------------------------------------------------------------------|
    | `#{parent_pointer}/attributes/active_period` | Exact Date/Time ranges alert is active                                                   |
    | `#{parent_pointer}/attributes/lifecycle`     | Enumerated, machine-readable description of `#{parent_pointer}/attributes/active_period` |
    | `#{parent_pointer}/attributes/timeframe`     | Human-readable description of `#{parent_pointer}/attributes/active_period`               |
    """
  end

  defp typedoc(type) do
    {:docs_v1, _, :elixir, _, _, _, details} = Code.fetch_docs(Model.Alert)

    for(
      {{:type, ^type, _}, _, _, %{"en" => module_doc}, _} <- details,
      do: module_doc
    )
    |> hd()
  end
end
