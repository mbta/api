defmodule State.Shape do
  @moduledoc """

  Maintains the list of Shapes.  Can by queried by ID or route ID.

  """
  use State.Server,
    indices: [:id],
    recordable: Model.Shape

  alias Events.Gather
  alias Model.{Direction, Route, Shape}
  alias Parse.Polyline

  @subscriptions [
    {:fetch, "shapes.txt"},
    {:new_state, State.RoutePattern},
    {:new_state, State.Schedule},
    {:new_state, State.Stop},
    {:new_state, State.Trip}
  ]

  @doc """
  Select shapes provided a list of route ids and direction id.
  """
  @spec select_routes([Route.id()], Direction.id() | nil) :: [Shape.t()]
  def select_routes(route_ids, direction_id) do
    opts =
      case direction_id do
        id when id in [0, 1] -> %{routes: route_ids, direction_id: id}
        _ -> %{routes: route_ids}
      end

    opts
    |> State.Trip.filter_by()
    |> Enum.map(& &1.shape_id)
    |> Enum.uniq()
    |> by_ids()
    |> Enum.sort_by(&{-&1.priority, &1.name})
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
  def handle_new_state([%Polyline{} | _] = polylines) do
    super(fn ->
      trips_by_shape =
        State.Trip.all()
        |> Enum.group_by(& &1.shape_id)
        |> Map.new()

      polylines
      |> Enum.flat_map(&shape_from_polyline(&1, Map.get(trips_by_shape, &1.id, [])))
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

    handle_new_state(polylines)
  end

  defp shape_from_polyline(polyline, trips)

  defp shape_from_polyline(_, []) do
    []
  end

  defp shape_from_polyline(%Polyline{} = polyline, trips) do
    trip =
      trips
      |> Enum.filter(&(Model.Trip.primary?(&1) && &1.route_pattern_id))
      |> Enum.min_by(&State.RoutePattern.by_id(&1.route_pattern_id).sort_order, fn -> nil end)

    shape_from_trips_for_polyline(polyline, trip, trips)
  end

  defp shape_from_trips_for_polyline(polyline, trip, trips)

  defp shape_from_trips_for_polyline(_polyline, nil, []) do
    []
  end

  defp shape_from_trips_for_polyline(polyline, nil, trips) do
    [trip] =
      trips
      |> sort_by_number_of_trips_with_headsign()
      |> Enum.sort_by(& &1.alternate_route)
      |> Enum.take(1)

    [
      %Shape{
        id: polyline.id,
        route_id: trip.route_id,
        direction_id: trip.direction_id,
        name: trip.headsign,
        polyline: polyline.polyline,
        priority: 1
      }
    ]
  end

  defp shape_from_trips_for_polyline(polyline, trip, _trips) do
    route_pattern = State.RoutePattern.by_id(trip.route_pattern_id)

    priority =
      case route_pattern.typicality do
        1 -> 2
        2 -> 1
        3 -> 0
        4 -> -1
      end

    [
      %Shape{
        id: polyline.id,
        route_id: trip.route_id,
        direction_id: trip.direction_id,
        name: route_pattern.name,
        polyline: polyline.polyline,
        priority: priority
      }
    ]
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
    prefix_overrides = config[:prefix_overrides]
    suffix_overrides = config[:suffix_overrides]

    shapes
    |> Enum.map(fn %{id: id} = shape ->
      case find_override(id, prefix_overrides, suffix_overrides) do
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

  defp find_override(id, prefix_overrides, suffix_overrides) do
    Enum.find_value(
      [{&String.starts_with?/2, prefix_overrides}, {&String.ends_with?/2, suffix_overrides}],
      fn {check_fn, overrides} ->
        find_override_priority(check_fn, overrides, id)
      end
    )
  end

  defp find_override_priority(check_fn, overrides, id) when is_function(check_fn, 2) do
    Enum.find_value(overrides, fn {check_value, priority} ->
      if check_fn.(id, check_value), do: priority
    end)
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
end
