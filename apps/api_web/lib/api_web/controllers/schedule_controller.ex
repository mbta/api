defmodule ApiWeb.ScheduleController do
  @moduledoc """
  Controller for Schedules. Filterable by:

  * stop
  * route
  * direction ID
  * service date
  * trip
  * stop sequence
  """
  use ApiWeb.Web, :api_controller

  alias State.Schedule

  plug(ApiWeb.Plugs.ValidateDate)
  plug(:date)

  @filters ~w(date direction_id max_time min_time route stop stop_sequence
              trip)s
  @pagination_opts ~w(offset limit order_by)a

  def state_module, do: State.Schedule

  def show_data(_conn, _params), do: []

  swagger_path :index do
    get(path(__MODULE__, :index))

    description("""
    **NOTE:** `filter[route]`, `filter[stop]`, or `filter[trip]` **MUST** be present for any schedules to be returned.

    List of schedules.  To get a realtime prediction instead of the scheduled times, use `/predictions`.

    #{swagger_path_description("/data/{index}")}

    ## When a vehicle is scheduled to be at a stop

    `/schedules?filter[stop]=STOP_ID`

    ## The schedule for one route

    `/schedules?filter[route]=ROUTE_ID`

    ### When a route is open

    Query for the `first` and `last` stops on the route.

    `/schedules?filter[route]=ROUTE_ID&filter[stop_sequence]=first,last`

    ## The schedule for a whole trip

    `/schedule?filter[trip]=TRIP_ID`

    """)

    common_index_parameters(__MODULE__)
    include_parameters(~w(stop trip prediction route))
    filter_param(:date, description: "Filter schedule by date that they are active.")
    filter_param(:direction_id)

    filter_param(
      :time,
      name: :min_time,
      description:
        "Time before which schedule should not be returned. To filter times after midnight use more than 24 hours. For example, min_time=24:00 will return schedule information for the next calendar day, since that service is considered part of the current service day. Additionally, min_time=00:00&max_time=02:00 will not return anything."
    )

    filter_param(
      :time,
      name: :max_time,
      description:
        "Time after which schedule should not be returned. To filter times after midnight use more than 24 hours. For example, min_time=24:00 will return schedule information for the next calendar day, since that service is considered part of the current service day. Additionally, min_time=00:00&max_time=02:00 will not return anything."
    )

    filter_param(:id, name: :route)
    filter_param(:id, name: :stop)
    filter_param(:id, name: :trip)

    parameter(:"filter[stop_sequence]", :query, :string, """
    Filter by the index of the stop in the trip.  Symbolic values `first` and `last` can be used instead of \
    numeric sequence number too.
    """)

    consumes("application/vnd.api+json")
    produces("application/vnd.api+json")
    response(200, "OK", Schema.ref(:Schedules))
    response(400, "Bad Request", Schema.ref(:BadRequest))
    response(403, "Forbidden", Schema.ref(:Forbidden))
    response(429, "Too Many Requests", Schema.ref(:TooManyRequests))
  end

  def index_data(_conn, params) do
    case params
         |> Params.filter_params(@filters)
         |> format_filters() do
      filters when map_size(filters) > 1 ->
        # greater than 1 because `date` is automatically included
        filters
        |> Schedule.filter_by()
        |> State.all(Params.filter_opts(params, @pagination_opts))

      _ ->
        {:error, :filter_required}
    end
  end

  # Formats the filters we care about into map with parsed values
  @spec format_filters(map) :: map
  defp format_filters(filters) do
    filters
    |> Stream.flat_map(&do_format_filter/1)
    |> Enum.into(%{})
    |> Map.put_new_lazy(:date, &Parse.Time.service_date/0)
  end

  # Parse the keys we care about
  @spec do_format_filter({String.t(), String.t()}) :: %{atom: any} | []
  defp do_format_filter({key, string}) when key in ["stop", "trip", "route"] do
    case Params.split_on_comma(string) do
      [] ->
        []

      ids ->
        %{String.to_existing_atom("#{key}s") => ids}
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

  defp do_format_filter({"date", date}) do
    case Date.from_iso8601(date) do
      {:ok, date} ->
        %{date: date}

      _ ->
        []
    end
  end

  defp do_format_filter({"stop_sequence", stop_sequence_str}) do
    case Params.split_on_comma(stop_sequence_str) do
      [] ->
        []

      stop_sequence ->
        formatted_stop_sequence =
          stop_sequence
          |> Stream.map(&format_stop/1)
          |> Enum.reject(&is_nil/1)

        if formatted_stop_sequence != [] do
          %{stop_sequence: formatted_stop_sequence}
        else
          []
        end
    end
  end

  defp do_format_filter({key, time}) when key in ["min_time", "max_time"] do
    case time_to_seconds_past_midnight(time) do
      nil ->
        []

      time_in_seconds ->
        %{String.to_existing_atom(key) => time_in_seconds}
    end
  end

  defp do_format_filter(_), do: []

  defp format_stop("first"), do: :first
  defp format_stop("last"), do: :last

  defp format_stop(stop) do
    case Integer.parse(stop) do
      {stop_id, ""} ->
        stop_id

      _ ->
        nil
    end
  end

  defp time_to_seconds_past_midnight(<<hour_bin::binary-2, ?:, minute_bin::binary-2>>) do
    time_to_seconds_past_midnight(hour_bin, minute_bin)
  end

  defp time_to_seconds_past_midnight(<<hour_bin::binary-1, ?:, minute_bin::binary-2>>) do
    time_to_seconds_past_midnight(hour_bin, minute_bin)
  end

  defp time_to_seconds_past_midnight(_) do
    nil
  end

  defp time_to_seconds_past_midnight(hour_bin, minute_bin) do
    with {hour, ""} <- Integer.parse(hour_bin),
         {minute, ""} <- Integer.parse(minute_bin) do
      hour * 3_600 + minute * 60
    else
      _ ->
        nil
    end
  end

  @doc """
  Assigns a datetime to the conn. If a valid date is passed as a param, that
  value is used. Otherwise a default value of today is used.
  """
  def date(%{params: params} = conn, []) do
    {conn, date} =
      with date_string when date_string != nil <- Params.filter_params(params, ["date"])["date"],
           {:ok, parsed_date} <- Date.from_iso8601(date_string) do
        {conn, parsed_date}
      else
        _ -> conn_service_date(conn)
      end

    conn
    |> assign(:date, date)
    |> assign(:date_seconds, DateHelpers.unix_midnight_seconds(date))
  end

  def swagger_definitions do
    import PhoenixSwagger.JsonApi, except: [page: 1]

    %{
      ScheduleResource:
        resource do
          description(swagger_path_description("*"))

          attributes do
            arrival_time(
              :string,
              """
              Time when the trip arrives at the given stop.  `null` if the first stop \
              (`*/relationships/stop/data/id`) on the trip (`*/relationships/trip/data/id`).  See \
              [GTFS `stop_times.txt` `arrival_time`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
              Format is ISO8601.
              """,
              format: :"date-time",
              example: "2017-08-14T15:04:00-04:00"
            )

            departure_time(
              :string,
              """
              Time when the trip departs the given stop. `null` if the last stop \
              (`*/relationships/stop/data/id`) on the trip (`*/relationships/trip/data/id`).  See \
              [GTFS `stop_times.txt` `departure_time`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
              Format is ISO8601.
              """,
              format: :"date-time",
              example: "2017-08-14T15:04:00-04:00"
            )

            stop_sequence(
              :integer,
              """
              The sequence the `stop_id` is arrived at during the `trip_id`.  The stop sequence is \
              monotonically increasing along the trip, but the `stop_sequence` along the `trip_id` are not \
              necessarily consecutive.  See \
              [GTFS `stop_times.txt` `stop_sequence`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
              """,
              example: 1
            )

            pickup_type(
              %Schema{type: :integer, enum: Enum.to_list(0..3)},
              """
              How the vehicle departs from `stop_id`.

              | Value | Description                                   |
              |-------|-----------------------------------------------|
              | `0`   | Regularly scheduled pickup                    |
              | `1`   | No pickup available                           |
              | `2`   | Must phone agency to arrange pickup           |
              | `3`   | Must coordinate with driver to arrange pickup |

              See \
              [GTFS `stop_times.txt` `pickup_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
              """,
              example: 0
            )

            drop_off_type(
              %Schema{type: :integer, enum: Enum.to_list(0..3)},
              """
              How the vehicle arrives at `stop_id`.

              | Value | Description                                   |
              |-------|-----------------------------------------------|
              | `0`   | Regularly scheduled drop off                  |
              | `1`   | No drop off available                         |
              | `2`   | Must phone agency to arrange pickup           |
              | `3`   | Must coordinate with driver to arrange pickup |

              See \
              [GTFS `stop_times.txt` `drop_off_type`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
              """,
              example: 1
            )

            timepoint(
              :boolean,
              """
              | Value   | `*/attributes/arrival_time` and `*/attributes/departure_time` |
              |---------|---------------------------------------------------------------|
              | `true`  | Exact                                                         |
              | `false` | Estimates                                                     |

              See \
              [GTFS `stop_times.txt` `timepoint`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt)
              """,
              example: false
            )
          end

          direction_id_attribute()
          relationship(:route)
          relationship(:trip)
          relationship(:stop)
          relationship(:prediction)
        end,
      Schedules: page(:ScheduleResource)
    }
  end

  defp swagger_path_description(parent_pointer) do
    """
    A schedule is the arrival drop off (`#{parent_pointer}/attributes/drop_off_type`) time \
    (`#{parent_pointer}/attributes/arrival_time`) and departure pick up (`#{parent_pointer}/attributes/pickup_type`) \
    time (`#{parent_pointer}/attributes/departure_time`) to/from a stop \
    (`#{parent_pointer}/relationships/stop/data/id`) at a given sequence \
    (`#{parent_pointer}/attributes/stop_sequence`) along \
    a trip (`#{parent_pointer}/relationships/trip/data/id`) going in a direction \
    (`#{parent_pointer}/attributes/direction_id`) on a route (`#{parent_pointer}/relationships/route/data/id`) when \
    the trip is following a service (`#{parent_pointer}/relationships/service/data/id`) to determine when it is active.

    See [GTFS `stop_times.txt`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#stop_timestxt) for base specification.
    """
  end
end
