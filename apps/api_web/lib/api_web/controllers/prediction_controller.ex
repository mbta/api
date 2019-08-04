defmodule ApiWeb.PredictionController do
  @moduledoc """
  Controller for predictions.  Filterable on:

  * latitude/longitude
  * stop
  * route
  * trip
  * radius
  """
  use ApiWeb.Web, :api_controller
  require Logger
  alias State.Prediction

  @filters ~w(stop route trip latitude longitude radius direction_id stop_sequence route_type date route_pattern)s
  @pagination_opts ~w(offset limit order_by)a
  @includes ~w(schedule stop route trip vehicle alerts)

  plug(:date)

  def state_module, do: State.Prediction

  def show_data(_conn, _params), do: []

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    **NOTE:** A filter **MUST** be present for any predictions to be returned.

    List of predictions for trips.  To get the scheduled times instead of the predictions, use `/schedules`.

    #{swagger_path_description("/data/{index}")}

    ## When a vehicle is predicted to be at a stop

    `/predictions?filter[stop]=STOP_ID`

    ## The predicted schedule for one route

    `/predictions?filter[route]=ROUTE_ID`

    ## The predicted schedule for a whole trip

    `/predictions?filter[trip]=TRIP_ID`

    """)

    common_index_parameters(__MODULE__, :prediction, :include_time)

    include_parameters(
      @includes,
      description: include_example()
    )

    filter_param(:position)
    filter_param(:radius)
    filter_param(:direction_id)
    filter_param(:route_type)
    filter_param(:id, name: :stop)
    filter_param(:id, name: :route)
    filter_param(:id, name: :trip)

    parameter("filter[route_pattern]", :query, :string, """
    Filter by `/included/{index}/relationships/route_pattern/data/id` of a trip. Multiple `route_pattern_id` #{
      comma_separated_list()
    }.
    """)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Predictions))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(conn, params) do
    with {:ok, filtered_params} <- Params.filter_params(params, @filters, conn),
         {:ok, _includes} <- Params.validate_includes(params, @includes, conn) do
      pagination_opts =
        Params.filter_opts(params, @pagination_opts, conn, order_by: {:arrival_time, :asc})

      stop_ids = stop_ids(filtered_params, conn)
      route_ids = Params.split_on_comma(filtered_params, "route")
      route_pattern_ids = Params.split_on_comma(filtered_params, "route_pattern")
      route_types = Params.route_types(filtered_params)

      direction_id_matcher =
        filtered_params
        |> Params.direction_id()
        |> direction_id_matcher()

      matchers = stop_sequence_matchers(filtered_params, direction_id_matcher)

      case filtered_params do
        %{"route_type" => _} = p when map_size(p) == 1 ->
          {:error, :only_route_type}

        p when map_size(p) > 0 ->
          filtered_params
          |> Params.split_on_comma("trip")
          |> case do
            [] ->
              case route_pattern_ids do
                [] ->
                  all_stops_and_routes(stop_ids, route_ids, matchers)

                route_pattern_ids ->
                  all_stops_and_route_patterns(stop_ids, route_pattern_ids, matchers)
              end

            trip_ids ->
              all_stops_and_trips(stop_ids, trip_ids, matchers)
          end
          |> Prediction.filter_by_route_type(route_types)
          |> State.all(pagination_opts)

        _ ->
          {:error, :filter_required}
      end
    else
      {:error, _, _} = error -> error
    end
  end

  defp stop_ids(params, conn) do
    case Params.fetch_coords(params) do
      :error ->
        params
        |> Params.split_on_comma("stop")
        |> include_legacy_stop_ids(conn.assigns.api_version)
        |> State.Stop.location_type_0_ids_by_parent_ids()

      {:ok, {latitude, longitude, radius}} ->
        stops = State.Stop.around(latitude, longitude, radius)

        stops
        |> Enum.sort_by(GeoDistance.cmp(latitude, longitude))
        |> Enum.map(& &1.id)
    end
  end

  defp include_legacy_stop_ids(ids, version) when version >= "2019-02-12" do
    ids
  end

  defp include_legacy_stop_ids(ids, version) when version >= "2018-07-23" do
    include_legacy_stop_ids_2019_02_12(ids)
  end

  defp include_legacy_stop_ids(ids, _version) do
    ids
    |> include_legacy_stop_ids_2019_02_12
    |> include_legacy_stop_ids_2018_07_23
  end

  defp include_legacy_stop_ids_2019_02_12(ids) do
    Enum.flat_map(
      ids,
      fn
        "70061" ->
          [
            "70061",
            "Alewife-01",
            "Alewife-02"
          ]

        "70105" ->
          [
            "70105",
            "Braintree-01",
            "Braintree-02"
          ]

        "70036" ->
          ["70036", "Oak Grove-01", "Oak Grove-02"]

        "70001" ->
          ["70001", "Forest Hills-01", "Forest Hills-02"]

        "70200" ->
          ["70200", "71199"]

        "70150" ->
          ["70150", "71150"]

        "70151" ->
          ["70151", "71151"]

        id when id in ["70201", "70202"] ->
          [id, "Government Center-Brattle"]

        id ->
          [id]
      end
    )
  end

  defp include_legacy_stop_ids_2018_07_23(ids) do
    Enum.flat_map(
      ids,
      fn
        "South Station" ->
          [
            "South Station",
            "South Station-01",
            "South Station-02",
            "South Station-03",
            "South Station-04",
            "South Station-05",
            "South Station-06",
            "South Station-07",
            "South Station-08",
            "South Station-09",
            "South Station-10",
            "South Station-11",
            "South Station-12",
            "South Station-13"
          ]

        "North Station" ->
          [
            "North Station",
            "North Station-01",
            "North Station-02",
            "North Station-03",
            "North Station-04",
            "North Station-05",
            "North Station-06",
            "North Station-07",
            "North Station-08",
            "North Station-09",
            "North Station-10"
          ]

        "Back Bay" ->
          ["Back Bay", "Back Bay-01", "Back Bay-02", "Back Bay-03", "Back Bay-05", "Back Bay-07"]

        id ->
          [id]
      end
    )
  end

  defp all_stops_and_routes([] = _stop_ids, [] = _route_ids, _matchers), do: []

  defp all_stops_and_routes(stop_ids, [], matchers) do
    for stop_id <- stop_ids,
        matcher <- matchers do
      Map.put(matcher, :stop_id, stop_id)
    end
    |> Prediction.select(:stop_id)
  end

  defp all_stops_and_routes([], route_ids, matchers) do
    for route_id <- route_ids,
        matcher <- matchers do
      Map.put(matcher, :route_id, route_id)
    end
    |> Prediction.select(:route_id)
  end

  defp all_stops_and_routes(stop_ids, route_ids, matchers) do
    for stop_id <- stop_ids,
        route_id <- route_ids,
        matcher <- matchers do
      Map.merge(matcher, %{
        stop_id: stop_id,
        route_id: route_id
      })
    end
    |> Prediction.select(:stop_id)
  end

  defp all_stops_and_trips([], trip_ids, matchers) do
    for trip_id <- trip_ids,
        matcher <- matchers do
      Map.put(matcher, :trip_id, trip_id)
    end
    |> Prediction.select(:trip_id)
  end

  defp all_stops_and_trips(stop_ids, trip_ids, matchers) do
    for stop_id <- stop_ids,
        trip_id <- trip_ids,
        matcher <- matchers do
      Map.merge(matcher, %{stop_id: stop_id, trip_id: trip_id})
    end
    |> Prediction.select(:stop_id)
  end

  defp all_stops_and_route_patterns([], route_pattern_ids, matchers) do
    for route_pattern_id <- route_pattern_ids,
        matcher <- matchers do
      Map.put(matcher, :route_pattern_id, route_pattern_id)
    end
    |> Prediction.select(:route_pattern_id)
  end

  defp all_stops_and_route_patterns(stop_ids, route_pattern_ids, matchers) do
    for route_pattern_id <- route_pattern_ids,
        stop_id <- stop_ids,
        matcher <- matchers do
      Map.merge(matcher, %{route_pattern_id: route_pattern_id, stop_id: stop_id})
    end
    |> Prediction.select(:stop_id)
  end

  defp direction_id_matcher(nil), do: %{}

  defp direction_id_matcher(direction_id) do
    %{direction_id: direction_id}
  end

  defp stop_sequence_matchers(params, direction_id_matcher) do
    case Params.split_on_comma(params, "stop_sequence") do
      [_ | _] = strs ->
        for str <- strs,
            {stop_sequence, ""} <- [Integer.parse(str)] do
          Map.put(direction_id_matcher, :stop_sequence, stop_sequence)
        end

      [] ->
        [direction_id_matcher]
    end
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      PredictionResource:
        resource do
          description(swagger_path_description("*"))

          attributes do
            arrival_time(
              [:string, :null],
              """
              When the vehicle is now predicted to arrive.  `null` if the first stop \
              (`*/relationships/stop/data/id`) on the trip (`*/relationships/trip/data/id`). See \
              [GTFS `Realtime` `FeedMessage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `arrival`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
              Format is ISO8601.
              """,
              example: "2017-08-14T15:38:58-04:00"
            )

            departure_time(
              [:string, :null],
              """
              When the vehicle is now predicted to depart.  `null` if the last stop \
              (`*/relationships/stop/data/id`) on the trip (`*/relationships/trip/data/id`). See \
              [GTFS `Realtime` `FeedMessage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `departure`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
              Format is ISO8601.
              """,
              example: "2017-08-14T15:38:58-04:00"
            )

            schedule_relationship(
              [:string, :null],
              """
              How the predicted stop relates to the `Model.Schedule.t` stops.

              | Value           | Description |
              |-----------------|-------------|
              | `"ADDED"`       | An extra trip that was added in addition to a running schedule, for example, to replace a broken vehicle or to respond to sudden passenger load. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship` `ADDED`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1) |
              | `"CANCELLED"`   | A trip that existed in the schedule but was removed. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship` `CANCELED`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1) |
              | `"NO_DATA"`     | No data is given for this stop. It indicates that there is no realtime information available. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `ScheduleRelationship` `NO_DATA`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship) |
              | `"SKIPPED"`     | The stop was originally scheduled, but was skipped. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `ScheduleRelationship`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship) |
              | `"UNSCHEDULED"` | A trip that is running with no schedule associated to it. See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship` `UNSCHEDULED`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1) |
              | `null`          | Stop was scheduled.  See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship` `SCHEDULED`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1) |

              See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor` `ScheduleRelationship`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship-1)
              See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `ScheduleRelationship`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#enum-schedulerelationship)
              """,
              example: "UNSCHEDULED"
            )

            stop_sequence(
              [:integer, :null],
              """
              The sequence the stop (`*/relationships/stop/data/id`) is arrived at during the trip \
              (`*/relationships/trip/data/id`).  The stop sequence is monotonically increasing along the \
              trip, but the `stop_sequence` along the trip are not necessarily consecutive.

              See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate` `stop_sequence`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate).
              """,
              example: 19
            )

            status(:string, "Status of the schedule", example: "Approaching")
          end

          direction_id_attribute()
          relationship(:trip)
          relationship(:stop)
          relationship(:route)
          relationship(:vehicle)
          relationship(:schedule)
          relationship(:alerts, type: :has_many)
        end,
      Predictions: page(:PredictionResource)
    }
  end

  @doc "Used when including schedules"
  def date(conn, []) do
    {conn, date} = conn_service_date(conn)

    conn
    |> assign(:date, date)
    |> assign(:date_seconds, DateHelpers.unix_midnight_seconds(date))
  end

  defp swagger_path_description(parent_pointer) do
    """
    The predicted arrival time (`/#{parent_pointer}/attributes/arrival_time`) and departure time \
    (`#{parent_pointer}/attributes/departure_time`) to/from a stop (`#{parent_pointer}/relationships/stop/data/id`) at \
    a given sequence (`#{parent_pointer}/attriutes/stop_sequence`) along a trip \
    (`#{parent_pointer}/relationships/trip/data/id`) going a direction (`#{parent_pointer}/attributes/direction_id`) \
    along a route (`#{parent_pointer}/relationships/route/data/id`).

    See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `TripDescriptor`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-tripdescriptor)
    See [GTFS Realtime `FeedMesage` `FeedEntity` `TripUpdate` `StopTimeUpdate`](https://github.com/google/transit/blob/master/gtfs-realtime/spec/en/reference.md#message-stoptimeupdate)
    """
  end

  defp include_example do
    """
    Here is an example:
    `https://api-v3.mbta.com/predictions?filter%5Bstop%5D=place-sstat&filter%5Bdirection_id%5D=0&include=stop`
    returns predictions from South Station with direction_id=0, below is a truncated response with only relevant fields displayed:
    ```
      {
        "data": [
          {
            "id": "prediction-CR-Weekday-Fall-18-743-South Station-02-1",
            "relationships": {
              "stop": {
                "data": {
                  "id": "South Station-02",
                  "type": "stop"
                }
              },
            },
            "type": "prediction"
          }
        ],
        "included": [
          {
            "attributes": {
              "platform_code": "2",
            },
            "id": "South Station-02",
            "type": "stop"
          }
        ],
      }
    ```
    Note the stop relationship; use it to cross-reference  stop-id with the included stops to retrieve the platform_code for the given prediction.
    """
  end
end
