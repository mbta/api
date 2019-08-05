defmodule State.Stop do
  @moduledoc """
  State for Stops. Supervises a cache as well as workers
  for the R* tree for geo lookups.
  """
  use Supervisor
  alias Model.{Stop, WGS84}
  alias State.{Route, RoutesPatternsAtStop, ServiceByDate, StopsOnRoute}

  @worker_count 5

  @type filter_opts :: %{
          optional(:routes) => [Model.Route.id()],
          optional(:direction_id) => Model.Direction.id(),
          optional(:date) => Date.t(),
          optional(:longitude) => WGS84.longitude(),
          optional(:latitude) => WGS84.latitude(),
          optional(:radius) => State.Stop.List.radius(),
          optional(:route_types) => [Model.Route.route_type()],
          optional(:location_type) => [Stop.location_type()]
        }

  @type post_search_filter_opts :: %{
          optional(:route_types) => [Model.Route.route_type()]
        }

  @type stop_search :: (() -> [Stop.t()])

  def start_link do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def stop do
    Supervisor.stop(__MODULE__)
  end

  def new_state(list_of_stops) do
    :ok = State.Stop.Cache.new_state(list_of_stops)

    for worker_id <- worker_range() do
      :ok = State.Stop.Worker.new_state(worker_id, list_of_stops)
    end

    Events.publish({:new_state, State.Stop}, size())
    :ok
  end

  def all do
    State.Stop.Cache.all()
  end

  def size do
    State.Stop.Cache.size()
  end

  def by_id(id) do
    State.Stop.Cache.by_id(id)
  end

  def by_ids(ids) do
    State.Stop.Cache.by_ids(ids)
  end

  def by_family_ids(ids) do
    State.Stop.Cache.query([
      %{id: ids},
      %{parent_station: ids}
    ])
  end

  def by_parent_station(id) when is_binary(id) do
    State.Stop.Cache.by_parent_station(id)
  end

  def by_parent_station(nil) do
    []
  end

  def by_location_type(location_types) do
    State.Stop.Cache.by_location_types(location_types)
  end

  def siblings(id) when is_binary(id) do
    case by_id(id) do
      %{parent_station: station_id} ->
        by_parent_station(station_id)

      nil ->
        []
    end
  end

  @doc """
  Return the location_type 0 stop IDs given their ID or a parent's ID.
  Useful for querying schedules or predictions, where the stop ID can only be location_type 0.
  """
  def location_type_0_ids_by_parent_ids(ids) do
    [
      %{
        id: ids,
        location_type: [0]
      },
      %{
        parent_station: ids,
        location_type: [0]
      }
    ]
    |> State.Stop.Cache.query()
    |> Enum.map(& &1.id)
  end

  @spec around(WGS84.latitude(), WGS84.longitude(), State.Stop.List.radius()) :: [Model.Stop.t()]
  def around(latitude, longitude, radius \\ 0.01) do
    random_worker()
    |> State.Stop.Worker.around(latitude, longitude, radius)
    |> by_ids
  end

  defp random_worker do
    Enum.random(worker_range())
  end

  defp worker_range do
    1..@worker_count
  end

  def family(%Stop{parent_station: nil, location_type: 1} = s) do
    # find the children and include them
    [s | State.Stop.Cache.by_parent_station(s.id)]
  end

  def family(%Stop{} = s) do
    # we already have a parent station, so only include ourself
    [s]
  end

  def family(_), do: []

  @doc """
  Applies a filtered search on Stops based on a map of filter values.

  The allowed filterable keys are:
    :ids
    :routes
    :direction_id
    :date
    :route_types
    :longitude
    :latitude
    :radius
    :location_type

  If filtering for :direction_id, :routes must also be applied for the
  direction filter to apply.

  If filtering for :date, :routes must also be applied for the date filter to
  apply.

  If filtering for a location, both :latitude and :longitude must be provided
  with :radius being optional.
  """
  @spec filter_by(filter_opts) :: [Stop.t()]
  def filter_by(filters) when is_map(filters) do
    filters
    |> build_filtered_searches()
    |> do_searches()
    |> do_post_search_filters(filters)
  end

  # Generate the functions needed to search concurrently
  @spec build_filtered_searches(filter_opts, [stop_search]) :: [stop_search]
  defp build_filtered_searches(filters, searches \\ [])

  defp build_filtered_searches(%{routes: route_ids} = filters, searches) do
    direction_opts =
      case Map.get(filters, :direction_id) do
        direction_id when direction_id != nil ->
          [direction_id: direction_id]

        _ ->
          []
      end

    date_opts =
      case Map.get(filters, :date) do
        date = %Date{} ->
          [service_ids: ServiceByDate.by_date(date)]

        _ ->
          []
      end

    opts = Keyword.merge(direction_opts, date_opts)

    search_operation = fn ->
      route_ids
      |> StopsOnRoute.by_route_ids(opts)
      |> by_ids()
    end

    filters
    |> Map.drop([:routes, :direction_id, :date])
    |> build_filtered_searches([search_operation | searches])
  end

  defp build_filtered_searches(%{latitude: lat, longitude: long} = filters, searches) do
    radius = filters[:radius] || 0.01

    search_operation = fn -> around(lat, long, radius) end

    filters
    |> Map.drop([:latitude, :longitude, :radius])
    |> build_filtered_searches([search_operation | searches])
  end

  defp build_filtered_searches(%{location_types: location_types} = filters, searches) do
    search_operation = fn -> by_location_type(location_types) end
    searches = [search_operation | searches]

    filters
    |> Map.drop([:location_types])
    |> build_filtered_searches(searches)
  end

  defp build_filtered_searches(%{ids: ids} = filters, searches) do
    search_operation = fn -> by_ids(ids) end
    searches = [search_operation | searches]

    filters
    |> Map.drop([:ids])
    |> build_filtered_searches(searches)
  end

  defp build_filtered_searches(_, searches), do: searches

  @spec do_searches([stop_search]) :: [Stop.t()]
  defp do_searches([]), do: all()

  defp do_searches(search_operations) when is_list(search_operations) do
    search_results =
      Stream.map(search_operations, fn search_operation ->
        case search_operation.() do
          results when is_list(results) ->
            results

          _ ->
            []
        end
      end)

    [first_result] = Enum.take(search_results, 1)

    search_results
    |> Stream.drop(1)
    |> Enum.reduce(first_result, fn results, acc ->
      acc_set = MapSet.new(acc)
      Enum.filter(results, fn stop -> stop in acc_set end)
    end)
    |> Enum.uniq_by(& &1.id)
  end

  @spec do_post_search_filters([Stop.t()], post_search_filter_opts) :: [Stop.t()]
  defp do_post_search_filters(stops, %{route_types: route_types} = filters) do
    stops
    |> Enum.filter(fn stop ->
      stop.id
      |> RoutesPatternsAtStop.routes_by_stop()
      |> Route.by_ids()
      |> Enum.any?(&(&1.type in route_types))
    end)
    |> do_post_search_filters(Map.delete(filters, :route_types))
  end

  defp do_post_search_filters(stops, _), do: stops

  def last_updated, do: State.Stop.Cache.last_updated()

  # Server callbacks

  def init(_) do
    workers =
      for i <- worker_range() do
        worker(State.Stop.Worker, [i], id: {:stop_worker, i})
      end

    children =
      [
        worker(State.Stop.Cache, []),
        {Registry, keys: :unique, name: State.Stop.Registry}
      ] ++
        workers ++
        [
          worker(State.Stop.Subscriber, [])
        ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
