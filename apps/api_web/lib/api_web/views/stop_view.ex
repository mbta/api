defmodule ApiWeb.StopView do
  use ApiWeb.Web, :api_view
  alias ApiWeb.Params
  import ApiWeb.StopController, only: [filters: 0]
  location("/stops/:url_safe_id")

  attributes([
    :name,
    :description,
    :address,
    :platform_code,
    :platform_name,
    :latitude,
    :longitude,
    :wheelchair_boarding,
    :location_type
  ])

  has_one(
    :parent_station,
    type: :stop,
    serializer: ApiWeb.StopView,
    field: :parent_station
  )

  has_one(
    :zone,
    type: :zone,
    field: :zone
  )

  has_many(
    :child_stops,
    type: :stop,
    serializer: ApiWeb.StopView,
    identifiers: :when_included,
    field: :child_stops
  )

  has_many(
    :recommended_transfers,
    type: :stop,
    serializer: ApiWeb.StopView,
    identifiers: :when_included,
    field: :recommended_transfers
  )

  has_many(
    :facilities,
    type: :facility,
    serializer: ApiWeb.FacilityView,
    links: [
      related: "/facilities/?filter[stop]=:url_safe_id"
    ]
  )

  def preload(stops, conn, include_opts) when is_list(stops) do
    stops = super(stops, conn, include_opts)

    if include_opts != nil and Keyword.has_key?(include_opts, :facilities) do
      stop_ids = Enum.map(stops, & &1.id)

      facilities_by_stop_id =
        stop_ids
        |> State.Facility.by_stop_ids()
        |> Enum.group_by(& &1.stop_id)

      for stop <- stops do
        Map.put(stop, :facilities, Map.get(facilities_by_stop_id, stop.id, []))
      end
    else
      stops
    end
  end

  def preload(stop, conn, include_opts) do
    super(stop, conn, include_opts)
  end

  def parent_station(%{parent_station: stop_id}, conn) do
    optional_relationship("parent_station", stop_id, &State.Stop.by_id/1, conn)
  end

  def child_stops(%{id: parent_id}, _conn) do
    State.Stop.by_parent_station(parent_id)
  end

  def recommended_transfers(%{id: stop_id}, _conn) do
    State.Transfer.recommended_transfers_from(stop_id)
  end

  def zone(%{id: stop_id}, _conn) do
    State.Stop.zone_id(stop_id)
  end

  def relationships(stop, %Plug.Conn{private: %{phoenix_view: __MODULE__}} = conn) do
    # only do this include if we're the top-level view, not if we're included
    # somewhere else
    relationships = super(stop, conn)

    with true <- split_included?("route", conn),
         {:ok, filtered} <- Params.filter_params(conn.params, filters(), conn),
         {:ok, route_id} <- Map.fetch(filtered, "route") do
      route = State.Route.by_id(route_id)

      put_in(relationships[:route], %HasOne{
        type: :route,
        name: :route,
        data: route,
        include: nil,
        identifiers: :always,
        serializer: ApiWeb.RouteView
      })
    else
      _ -> relationships
    end
  end

  def relationships(stop, conn) do
    super(stop, conn)
  end

  def facilities(%{facilities: facilities}, _conn) do
    # preloaded
    facilities
  end

  def facilities(%{id: stop_id}, _conn) do
    State.Facility.by_stop_id(stop_id)
  end
end
