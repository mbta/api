defmodule ApiWeb.ApiViewHelpers do
  @moduledoc """

  Helpers for JaSerializer views for loading and optionally loading
  relationship.

  """
  alias ApiWeb.Plugs.Deadline
  alias State.{Route, Stop, Trip, Vehicle}

  defmacro __using__(_) do
    quote do
      import ApiWeb.Router.Helpers, except: [url: 1]

      import ApiWeb.ApiViewHelpers,
        only: [
          optional_relationship: 4,
          split_included?: 2
        ]

      defdelegate stop(value, conn), to: ApiWeb.ApiViewHelpers
      defdelegate route(value, conn), to: ApiWeb.ApiViewHelpers
      defdelegate trip(value, conn), to: ApiWeb.ApiViewHelpers
      defdelegate vehicle(value, conn), to: ApiWeb.ApiViewHelpers

      def render("index." <> _, assigns) do
        unquote(__MODULE__).do_render(__MODULE__, Map.new(assigns))
      end

      def render("show." <> _, assigns) do
        unquote(__MODULE__).do_render(__MODULE__, Map.new(assigns))
      end

      defdelegate url_safe_id(struct, conn), to: ApiWeb.ApiViewHelpers

      def preload(data, _conn, nil) do
        data
      end

      def preload(data, conn, include_opts) do
        Enum.reduce(include_opts, data, fn key, data ->
          Deadline.check!(conn)
          ApiWeb.ApiViewHelpers.preload_for_key(key, data)
        end)
      end

      def attribute_set(_conn) do
        MapSet.new(__MODULE__.__attributes(), &Atom.to_string/1)
      end

      defoverridable preload: 3, attribute_set: 1
    end
  end

  def do_render(serializer, assigns) do
    args =
      assigns
      |> Map.put(:serializer, serializer)
      |> Map.put_new(:opts, %{})

    builder = JaSerializer.Builder.build(args)

    Deadline.check!(assigns.conn)

    builder
    |> JaSerializer.Formatter.format()
    |> log_record_count
  end

  defp log_record_count(%{"data" => list} = data) when is_list(list) do
    records = length(list) + length(Map.get(data, "included", []))
    _ = Logger.metadata(records: records)
    data
  end

  defp log_record_count(%{"data" => %{}} = data) do
    records = 1 + length(Map.get(data, "included", []))
    _ = Logger.metadata(records: records)
    data
  end

  @doc """

  Takes an include key, and does a bulk lookup of those IDs.  We take advange
  of structs being maps underneath and add the bulk-looked-up items as
  additional keys to each struct.

  """
  def preload_for_key({:stop, _}, [%{stop_id: _} | _] = data) do
    do_preload(data, &Stop.by_ids/1, :stop)
  end

  def preload_for_key({:route, _}, [%{route_id: _} | _] = data) do
    do_preload(data, &Route.by_ids/1, :route)
  end

  def preload_for_key({:trip, _}, [%{trip_id: _} | _] = data) do
    do_preload(data, &Trip.by_primary_ids/1, :trip)
  end

  def preload_for_key({:vehicle, _}, [%{vehicle_id: _} | _] = data) do
    do_preload(data, &Vehicle.by_ids/1, :vehicle)
  end

  def preload_for_key(_, data) do
    data
  end

  defp do_preload(data, fetch_fn, :trip) do
    do_preload_for_key(data, fetch_fn, :trip, &preload_trip_fallback/1)
  end

  defp do_preload(data, fetch_fn, key) do
    do_preload_for_key(data, fetch_fn, key, nil)
  end

  defp do_preload_for_key(data, fetch_fn, key, fallback_fn) do
    id_key = String.to_existing_atom("#{key}_id")

    ids =
      data
      |> Enum.map(&Map.get(&1, id_key))
      |> Enum.uniq()

    bulk_children = Map.new(fetch_fn.(ids), &{&1.id, &1})

    for item <- data do
      child_id = Map.get(item, id_key)

      child =
        if child = Map.get(bulk_children, child_id) do
          child
        else
          if is_nil(fallback_fn) do
            nil
          else
            fallback_fn.(child_id)
          end
        end

      Map.put(item, key, child)
    end
  end

  defp preload_trip_fallback(trip_id) do
    predictions = State.Prediction.by_trip_id(trip_id)

    if predictions == [] do
      nil
    else
      predictions
      |> State.Trip.Added.predictions_to_trips()
      |> Enum.take(1)
      |> List.first()
    end
  end

  def stop(%{stop: stop}, _conn) do
    stop
  end

  def stop(%{stop_id: stop_id}, conn) do
    optional_relationship("stop", stop_id, &Stop.by_id/1, conn)
  end

  def route(%{route: route}, _conn) do
    route
  end

  def route(%{route_id: route_id}, conn) do
    optional_relationship("route", route_id, &Route.by_id/1, conn)
  end

  def trip(%{trip: nil, trip_id: trip_id}, _conn), do: trip_id
  def trip(%{trip: trip}, _conn), do: trip

  def trip(%{trip_id: trip_id}, conn) do
    optional_relationship("trip", trip_id, &Trip.by_primary_id/1, conn)
  end

  def vehicle(%{vehicle: vehicle}, _conn) do
    vehicle
  end

  def vehicle(%{vehicle_id: vehicle_id}, conn) do
    optional_relationship("vehicle", vehicle_id, &Vehicle.by_id/1, conn)
  end

  def vehicle(%{trip_id: trip_id}, _conn) do
    case Vehicle.by_trip_id(trip_id) do
      [] -> nil
      [vehicle] -> vehicle
    end
  end

  def optional_relationship(relationship, id, fetch_fn, conn)

  def optional_relationship(_, nil, _, _) do
    nil
  end

  def optional_relationship(_, "", _, _) do
    nil
  end

  def optional_relationship(relationship, id, fetch, conn) do
    if split_included?(relationship, conn) do
      fetch.(id)
    else
      id
    end
  end

  @doc "Returns whether the given data type should be included in the response"
  @spec split_included?(String.t(), Plug.Conn.t()) :: boolean
  def split_included?(relationship, conn)

  def split_included?(relationship, %Plug.Conn{assigns: %{split_include: []}})
      when is_binary(relationship) do
    false
  end

  def split_included?(relationship, %Plug.Conn{assigns: %{split_include: set}})
      when is_binary(relationship) do
    MapSet.member?(set, relationship)
  end

  def split_included?(relationship, %Plug.Conn{}) when is_binary(relationship) do
    false
  end

  @doc """
  Takes a struct and its id and formats it to be safe URL Links.
  """
  @spec url_safe_id(%{id: String.t() | integer}, Plug.Conn.t()) :: String.t()
  def url_safe_id(%{id: id}, _conn) do
    id
    |> to_string()
    |> URI.encode()
    |> String.replace("/", "%2F")
  end

  def default_registered_per_interval() do
    ApiWeb.RateLimiter.max_registered_per_interval()
  end

  def limit(%ApiAccounts.Key{} = key) do
    key
    |> ApiWeb.User.from_key()
    |> ApiWeb.RateLimiter.max_requests()
    |> trunc()
  end

  def limit_value(%ApiAccounts.Key{} = key) do
    key
    |> ApiWeb.User.from_key()
    |> limit_or_default_of_nil()
  end

  defp limit_or_default_of_nil(%ApiWeb.User{limit: nil}) do
    nil
  end

  defp limit_or_default_of_nil(%ApiWeb.User{} = user) do
    user
    |> ApiWeb.RateLimiter.max_requests()
    |> trunc()
  end

  def interval_name(clear_interval \\ ApiWeb.config(:rate_limiter, :clear_interval)) do
    case clear_interval do
      60_000 ->
        "Per-Minute Limit"

      3_600_000 ->
        "Hourly Limit"

      86_400_000 ->
        "Daily Limit"

      clear_interval ->
        second_limit = Float.round(clear_interval / 1000, 2)
        "Requests Per #{second_limit} Seconds"
    end
  end
end
