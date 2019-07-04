defmodule State.Alert.Filter do
  @moduledoc """
  Documented in State.Alert.filter_by/1.
  """
  alias State.Alert
  alias State.Alert.{ActivePeriod, InformedEntity, InformedEntityActivity}

  @doc false
  @spec filter_by(Alert.filter_opts()) :: [Model.Alert.t()]
  def filter_by(filter_opts) do
    filter_opts
    |> filter_to_list_of_ids
    |> filter_by_ids(filter_opts)
    |> filter_by_informed_entity_activity(filter_opts)
    |> filter_by_active_period(filter_opts)
    |> Alert.by_ids()
    |> filter_alerts_by_banner(filter_opts)
    |> filter_alerts_by_lifecycles(filter_opts)
    |> filter_alerts_by_severity(filter_opts)
  end

  defp filter_to_list_of_ids(filter_opts) when filter_opts == %{} do
    Alert.all_keys()
  end

  defp filter_to_list_of_ids(filter_opts) do
    filter_opts
    |> build_matchers()
    |> InformedEntity.match()
  end

  defp build_matchers(filter_opts) do
    filter_opts
    |> Enum.reduce([%{}], &do_build_matcher/2)
    |> reject_empty_matchers
    |> Enum.uniq()
  end

  defp do_build_matcher({:ids, values}, _acc) when is_list(values) do
    MapSet.new(values, fn id -> %{id: id} end)
  end

  defp do_build_matcher({:facilities, values}, acc) when is_list(values) do
    matchers_for_values(acc, :facility, values)
  end

  defp do_build_matcher({:stops, values}, acc) when is_list(values) do
    route_matchers =
      for route_id <- State.RoutesAtStop.by_family_stops(values),
          stop_id <- [nil | values] do
        %{route: route_id, stop: stop_id}
      end

    stop_matchers =
      for stop_id <- [nil | values] do
        %{stop: stop_id}
      end

    for matcher_list <- [route_matchers, stop_matchers],
        merge <- matcher_list,
        matcher <- acc do
      Map.merge(matcher, merge)
    end
  end

  defp do_build_matcher({:routes, values}, acc) when is_list(values) do
    for route_id <- values,
        for_route <- matchers_for_route_id(route_id),
        matcher <- acc do
      Map.merge(matcher, for_route)
    end
  end

  defp do_build_matcher({:route_types, values}, acc) when is_list(values) do
    matchers_for_values(acc, :route_type, values)
  end

  defp do_build_matcher({:direction_id, value}, acc) when value in [0, 1] do
    matchers_for_values(acc, :direction_id, [value])
  end

  defp do_build_matcher({:activities, values}, acc) when is_list(values) do
    # these are matched later
    acc
  end

  defp do_build_matcher({:trips, values}, acc) when is_list(values) do
    # we expand the match for trips, to include the route type, route, and
    # direction ID
    for trip_id <- values,
        for_trip <- matchers_for_trip_id(trip_id),
        matcher <- acc do
      Map.merge(matcher, for_trip)
    end
  end

  defp do_build_matcher({:banner, value}, acc) when is_boolean(value) do
    # these are filtered later
    acc
  end

  defp do_build_matcher({:severity, _}, acc) do
    # these are filtered later
    acc
  end

  defp do_build_matcher({:datetime, %DateTime{}}, acc) do
    # filtered later
    acc
  end

  defp do_build_matcher({:lifecycles, value}, acc) when is_list(value) do
    # filtered later
    acc
  end

  defp do_build_matcher({key, values}, _acc) do
    raise ArgumentError, "unknown filter option #{key}, values #{inspect(values)}"
  end

  defp matchers_for_values(acc, key, values) when is_list(values) do
    for value <- values,
        matcher <- acc do
      Map.put(matcher, key, value)
    end
  end

  defp matchers_for_trip_id(nil) do
    [%{trip: nil}]
  end

  defp matchers_for_trip_id(trip_id) do
    with %Model.Trip{} = trip <- State.Trip.by_primary_id(trip_id),
         %Model.Route{} = route <- State.Route.by_id(trip.route_id) do
      [
        %{
          route_type: route.type,
          route: trip.route_id,
          direction_id: trip.direction_id,
          trip: trip_id
        }
      ]
    else
      _ ->
        [%{trip: trip_id}]
    end
  end

  defp matchers_for_route_id(nil) do
    [%{route: nil}]
  end

  defp matchers_for_route_id(route_id) do
    case State.Route.by_id(route_id) do
      %Model.Route{} = route ->
        [
          %{
            route_type: route.type,
            route: route_id
          }
        ]

      _ ->
        [%{route: route_id}]
    end
  end

  # we don't want to include matchers with all nil values unless it's the
  # only matcher
  defp reject_empty_matchers([_] = matchers) do
    matchers
  end

  defp reject_empty_matchers(matchers) do
    Enum.reject(matchers, &empty_matcher?/1)
  end

  defp empty_matcher?(matcher) do
    Enum.all?(matcher, &is_nil(elem(&1, 1)))
  end

  defp filter_by_informed_entity_activity(alert_ids, filter_opts) do
    activities = Map.get(filter_opts, :activities, [])
    InformedEntityActivity.filter(alert_ids, activities)
  end

  defp filter_by_active_period(alert_ids, %{datetime: dt}) do
    ActivePeriod.filter(alert_ids, dt)
  end

  defp filter_by_active_period(alert_ids, _) do
    alert_ids
  end

  defp filter_by_ids([] = ids, _) do
    ids
  end

  defp filter_by_ids(ids, %{ids: ids_to_filter_by}) do
    Enum.filter(ids, &(&1 in ids_to_filter_by))
  end

  defp filter_by_ids(ids, _) do
    ids
  end

  defp filter_alerts_by_severity(alerts, %{severity: nil}) do
    alerts
  end

  defp filter_alerts_by_severity(alerts, %{severity: severities}) when is_list(severities) do
    severities = MapSet.new(severities)
    Enum.filter(alerts, &MapSet.member?(severities, &1.severity))
  end

  defp filter_alerts_by_severity(alerts, _) do
    # doesn't filter by severity if severity filter missing
    alerts
  end

  defp filter_alerts_by_banner(alerts, %{banner: banner?}) do
    Enum.reject(alerts, &(is_nil(&1.banner) == banner?))
  end

  defp filter_alerts_by_banner(alerts, _) do
    # doesn't filter by banner if banner filter missing
    alerts
  end

  defp filter_alerts_by_lifecycles(alerts, %{lifecycles: lifecycles}) do
    lifecycles = MapSet.new(lifecycles)
    Enum.filter(alerts, &MapSet.member?(lifecycles, &1.lifecycle))
  end

  defp filter_alerts_by_lifecycles(alerts, _) do
    alerts
  end
end
