defmodule ApiWeb.LiveFacilityView do
  @moduledoc """
  View for live Facility data like parking
  """
  use ApiWeb.Web, :api_view

  location("/live_facilities/:id")

  has_one(
    :facility,
    type: :facility,
    serializer: ApiWeb.FacilityView
  )

  attributes([:properties, :updated_at])

  def type(_, %{assigns: %{api_version: ver}}) when ver >= '2019-07-01', do: "live_facility"
  def type(_, _), do: "live-facility"

  def attributes(%{properties: properties, updated_at: updated_at}, _conn) do
    %{
      properties: Enum.map(properties, &property/1),
      updated_at: updated_at
    }
  end

  def id(%{facility_id: id}, _conn), do: id

  def facility(%{facility_id: id}, conn) do
    optional_relationship("facility", id, &State.Facility.by_id/1, conn)
  end

  defp property(property) do
    %{
      name: property.name,
      value: property.value
    }
  end
end
