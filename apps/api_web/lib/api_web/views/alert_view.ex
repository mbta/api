defmodule ApiWeb.AlertView do
  @moduledoc """
  View for Alert data
  """
  use ApiWeb.Web, :api_view

  alias State.{Facility, Route, Stop, Trip}

  location(:alert_location)

  def alert_location(alert, conn), do: alert_path(conn, :show, alert.id)

  attributes([
    :header,
    :short_header,
    :description,
    :effect,
    :cause,
    :severity,
    :created_at,
    :updated_at,
    :active_period,
    :informed_entity,
    :service_effect,
    :timeframe,
    :lifecycle,
    :banner,
    :url
  ])

  def active_period(%{active_period: periods}, _conn) do
    periods
    |> Enum.map(fn {start, stop} ->
      %{
        "start" => start,
        "end" => stop
      }
    end)
  end

  @doc """
  Builds the relationships for each informed entity and joins them together.
  If a relationships isn't included (via the URL), it won't be returned in the data either.
  """
  def relationships(alert, conn) do
    alert.informed_entity
    |> Enum.flat_map(&relationships_for_entities(&1, conn))
    |> Enum.group_by(& &1.name)
    |> Enum.flat_map(&join_relationships(&1, conn))
    |> Map.new()
  end

  defp relationships_for_entities(entity, conn) do
    entity
    |> Enum.flat_map(&relationships_for_entity_key(&1, conn))
  end

  defp join_relationships({name, [first | _] = relationships}, conn) do
    # only return relationships if we included them; the data is already
    # available in "informed_entity"
    if split_included?(Atom.to_string(name), conn) do
      data =
        relationships
        |> Enum.map(& &1.data)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)

      [{name, %{first | data: data}}]
    else
      []
    end
  end

  defp relationships_for_entity_key({:activities, _}, _) do
    []
  end

  defp relationships_for_entity_key({:direction_id, _}, _) do
    []
  end

  defp relationships_for_entity_key({:facility, facility}, conn) do
    [
      %HasMany{
        type: :facility,
        name: :facilities,
        data: optional_relationship("facilities", facility, &Facility.by_id/1, conn),
        identifiers: :always,
        serializer: ApiWeb.FacilityView
      }
    ]
  end

  defp relationships_for_entity_key({:route, route}, conn) do
    [
      %HasMany{
        type: :route,
        name: :routes,
        data: optional_relationship("routes", route, &Route.by_id/1, conn),
        identifiers: :always,
        serializer: ApiWeb.RouteView
      }
    ]
  end

  defp relationships_for_entity_key({:route_type, _}, _) do
    []
  end

  defp relationships_for_entity_key({:stop, stop}, conn) do
    [
      %HasMany{
        type: :stop,
        name: :stops,
        data: optional_relationship("stops", stop, &Stop.by_id/1, conn),
        identifiers: :always,
        serializer: ApiWeb.StopView
      }
    ]
  end

  defp relationships_for_entity_key({:trip, trip}, conn) do
    [
      %HasMany{
        type: :trip,
        name: :trips,
        data: optional_relationship("trips", trip, &Trip.by_primary_id/1, conn),
        identifiers: :always,
        serializer: ApiWeb.TripView
      }
    ]
  end
end
