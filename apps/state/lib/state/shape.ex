defmodule State.Shape do
  @moduledoc """

  Maintains the list of Shapes.  Can by queried by ID or route ID.

  """
  use State.Server,
    indices: [:route_id, :id],
    recordable: Model.Shape

  alias Events.Gather
  alias Model.{Direction, Route, Shape}
  alias Parse.{Polyline, Variant}

  @subscriptions [
    {:fetch, "shapes.txt"},
    {:new_state, State.Schedule},
    {:new_state, State.Stop},
    {:new_state, State.Trip}
  ]

  @doc """
  Select shapes provided a list of route ids and direction id.
  """
  @spec select_routes([Route.id()], Direction.id() | nil) :: [Shape.t()]
  def select_routes(route_ids, nil) do
    matchers = for route_id <- route_ids, do: %{route_id: route_id}
    do_select(matchers)
  end

  def select_routes(route_ids, direction_id) when direction_id in [0, 1] do
    matchers =
      for id <- route_ids do
        %{direction_id: direction_id, route_id: id}
      end

    do_select(matchers)
  end

  @doc """
  Returns the primary shape for the given id.
  """
  @spec by_primary_id(Shape.id()) :: Shape.t() | nil
  def by_primary_id(id) do
    id
    |> by_id()
    |> Enum.max_by(& &1.priority, fn -> nil end)
  end

  @impl Events.Server
  def handle_event(event, value, _, state) do
    state = %{state | data: Gather.update(state.data, event, value)}
    {:noreply, state, :hibernate}
  end

  @impl GenServer
  def init(_) do
    _ = super(nil)
    Enum.each(@subscriptions, &subscribe/1)
    state = %{data: Gather.new(@subscriptions, &do_gather/1), last_updated: nil}
    {:ok, state}
  end

  @impl State.Server
  def handle_new_state({polylines, variants}) do
    variant_map = Map.new(variants, &{&1.id, &1})

    super(fn ->
      polylines
      |> merge_with(variant_map)
      |> Enum.group_by(&{&1.route_id, &1.direction_id})
      |> Enum.flat_map(fn {_key, shapes} -> arrange_by_priority(shapes) end)
    end)
  end

  @impl State.Server
  def handle_new_state(other) do
    super(other)
  end

  defp do_gather(%{{:fetch, "shapes.txt"} => shapes_blob}) do
    polylines = Polyline.parse(shapes_blob)

    replacements =
      :state
      |> Application.app_dir("priv/trip_route_direction.csv")
      |> File.read!()

    variants =
      :state
      |> Application.app_dir("priv/shaperoutevariants.csv")
      |> File.read!()
      |> Variant.parse(replacements)

    handle_new_state({polylines, variants})
  end

  defp do_select(matchers) do
    matchers
    |> select(:route_id)
    |> Enum.sort_by(&{-&1.priority, &1.name})
  end

  defp merge_with(polylines, variant_map) do
    for polyline <- polylines,
        variant <- [Map.get(variant_map, polyline.id)],
        trip <- find_trips_for(polyline) do
      name = variant_name(variant, trip)
      priority = variant_priority(variant, trip)

      %Model.Shape{
        id: polyline.id,
        route_id: trip.route_id,
        direction_id: trip.direction_id,
        name: name,
        polyline: polyline.polyline,
        priority: priority
      }
    end
  end

  defp find_trips_for(%{id: id}) do
    for alternate_route <- [nil, false] do
      %{shape_id: id, alternate_route: alternate_route}
    end
    |> State.Trip.select()
    |> sort_by_number_of_trips_with_headsign
    |> Stream.uniq_by(&{&1.route_id, &1.direction_id})
  end

  defp sort_by_number_of_trips_with_headsign(trips) do
    # group them by the headsign, sort by the length, returning the more
    # popular headsigns first
    trips
    |> Enum.group_by(& &1.headsign)
    |> Enum.sort_by(&length(elem(&1, 1)), &>=/2)
    |> Stream.flat_map(&elem(&1, 1))
  end

  def arrange_by_priority(shapes) do
    shapes
    |> sort_longer_shapes_first
    |> increase_priority_of_first_shape
    |> override_priorities_from_configuration
    |> reduce_priority_of_subset_shapes
  end

  defp sort_longer_shapes_first(shapes) do
    Enum.sort_by(
      shapes,
      fn shape ->
        stop_count =
          shape
          |> stop_id_set
          |> MapSet.size()

        {shape.priority, stop_count, optional_byte_size(shape.polyline)}
      end,
      &>=/2
    )
  end

  defp increase_priority_of_first_shape([]) do
    []
  end

  defp increase_priority_of_first_shape([shape | rest]) do
    [
      %{shape | priority: shape.priority + 1}
      | rest
    ]
  end

  defp reduce_priority_of_subset_shapes(shapes) do
    shapes
    |> Enum.reduce({[], MapSet.new()}, &do_priority_reduction/2)
    |> elem(0)
    |> Enum.reverse()
  end

  defp override_priorities_from_configuration(shapes) do
    config = Application.fetch_env!(:state, :shape)
    overrides = config[:overrides]
    suffix_overrides = config[:suffix_overrides]

    shapes
    |> Enum.map(fn %{id: id} = shape ->
      case find_override(id, overrides, suffix_overrides) do
        nil ->
          shape

        {priority, name} ->
          %{shape | priority: priority || shape.priority, name: name}

        priority ->
          %{shape | priority: priority}
      end
    end)
    |> Enum.sort_by(& &1.priority, &>=/2)
  end

  defp find_override(id, overrides, suffix_overrides) do
    if priority = Map.get(overrides, id) do
      priority
    else
      Enum.find_value(suffix_overrides, fn {suffix, priority} ->
        if String.ends_with?(id, suffix) do
          priority
        end
      end)
    end
  end

  defp optional_byte_size(binary) when is_binary(binary), do: byte_size(binary)
  defp optional_byte_size(_), do: 0

  defp do_priority_reduction(shape, {shapes, stop_set}) do
    stops = stop_id_set(shape)

    shape =
      cond do
        MapSet.equal?(MapSet.new(), stops) ->
          # we haven't loaded the stops yet, so don't change the shape
          shape

        MapSet.subset?(stops, stop_set) ->
          # this shape has no new stops
          %{shape | priority: -1}

        true ->
          shape
      end

    {[shape | shapes], MapSet.union(stop_set, stops)}
  end

  defp stop_id_set(shape) do
    for trip <- State.Trip.match(%{route_id: shape.route_id, shape_id: shape.id}, :route_id),
        schedule <- State.Schedule.by_trip_id(trip.id),
        into: MapSet.new() do
      # use the parent station ID
      case State.Stop.by_id(schedule.stop_id) do
        %{id: id, parent_station: nil} -> id
        %{parent_station: id} -> id
      end
    end
  end

  defp variant_name(variant, trip)
  defp variant_name(%{name: name}, _trip), do: name
  defp variant_name(nil, %{headsign: headsign}), do: headsign

  defp variant_priority(variant, trip)

  defp variant_priority(nil, trip) do
    if Model.Trip.primary?(trip) do
      1
    else
      0
    end
  end

  defp variant_priority(%{primary?: true, replaced?: false}, _) do
    2
  end

  defp variant_priority(%{primary?: false}, _) do
    0
  end

  defp variant_priority(_, trip) do
    variant_priority(nil, trip)
  end
end
