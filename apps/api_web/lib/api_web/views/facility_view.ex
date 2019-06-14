defmodule ApiWeb.FacilityView do
  @moduledoc """
  View for Facility data
  """
  use ApiWeb.Web, :api_view

  location("/facilities/:id")

  has_one(
    :stop,
    type: :stop,
    serializer: ApiWeb.StopView
  )

  attributes([:long_name, :short_name, :type, :properties, :latitude, :longitude])

  def preload([_ | _] = facilities, conn, include_opts) do
    facilities = super(facilities, conn, include_opts)

    if load_properties?(conn) do
      property_map =
        facilities
        |> Enum.map(& &1.id)
        |> State.Facility.Property.by_facility_ids()
        |> Enum.group_by(& &1.facility_id)

      for facility <- facilities do
        properties = encode_properties(Map.get(property_map, facility.id, []))
        Map.put(facility, :properties, properties)
      end
    else
      facilities
    end
  end

  def preload(facility, conn, include_opts) do
    super(facility, conn, include_opts)
  end

  def attributes(%Model.Facility{} = facility, conn) do
    attrs = Map.take(facility, ~w(long_name short_name type properties latitude longitude)a)

    attrs =
      if conn.assigns.api_version < "2019-07-01",
        do: Map.put(attrs, :name, facility.long_name),
        else: attrs

    if Map.get(attrs, :properties) == nil and load_properties?(conn) do
      properties =
        facility.id
        |> State.Facility.Property.by_facility_id()
        |> encode_properties

      Map.put(attrs, :properties, properties)
    else
      attrs
    end
  end

  def type(_, _), do: "facility"

  defp load_properties?(conn) do
    # only fetch properties if they're included, or if we're using all fields
    fields = conn.assigns[:opts][:fields]["facility"] || []
    fields == [] or :properties in fields
  end

  defp encode_properties(properties) do
    for property <- properties do
      %{
        "name" => property.name,
        "value" => property.value
      }
    end
  end

  def attribute_set(%{assigns: %{api_version: ver}} = conn) when ver < "2019-07-01" do
    conn |> super() |> MapSet.put("name")
  end

  def attribute_set(conn), do: super(conn)
end
