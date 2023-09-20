defmodule State.Route do
  @moduledoc """
  Stores and indexes `Model.Route.t` from `routes.txt`.
  """

  use State.Server,
    indices: [:id, :type, :line_id],
    parser: Parse.Routes,
    recordable: Model.Route

  alias Events.Gather

  @impl GenServer
  def init(_) do
    _ = super(nil)

    subscriptions = [{:fetch, "directions.txt"}, {:fetch, "routes.txt"}]

    for sub <- subscriptions, do: Events.subscribe(sub)

    state = %{data: Gather.new(subscriptions, &do_gather/1), last_updated: nil}
    {:ok, state}
  end

  @impl Events.Server
  def handle_event(event, value, _, state) do
    state = %{state | data: Gather.update(state.data, event, value)}
    {:noreply, state, :hibernate}
  end

  @impl State.Server
  def post_load_hook(routes) do
    Enum.sort_by(routes, & &1.sort_order)
  end

  def do_gather(%{
        {:fetch, "directions.txt"} => directions_blob,
        {:fetch, "routes.txt"} => routes_blob
      }) do
    dmap = get_direction_map(directions_blob)
    routes = get_routes(routes_blob, dmap)
    handle_new_state(routes)
  end

  def get_direction_map(blob),
    do:
      blob
      |> Parse.Directions.parse()
      |> Enum.group_by(&{&1.route_id, &1.direction_id})

  def get_routes(routes_blob, direction_map),
    do:
      routes_blob
      |> Parse.Routes.parse()
      |> Enum.map(fn route ->
        %{
          route
          | direction_names: get_direction_details(direction_map, route.id, :direction),
            direction_destinations:
              get_direction_details(direction_map, route.id, :direction_destination)
        }
      end)

  defp get_direction_details(map, route_id, field) do
    for direction_id <- ["0", "1"] do
      case Map.get(map, {route_id, direction_id}, nil) do
        [d | _tail] ->
          case Map.fetch!(d, field) do
            "" -> nil
            value -> value
          end

        _ ->
          nil
      end
    end
  end

  def hidden?(%{listed_route: false}), do: true
  def hidden?(%{agency_id: agency_id}) when agency_id != "1", do: true
  def hidden?(_), do: false

  @spec by_id(Model.Route.id()) :: Model.Route.t() | nil
  def by_id(id) do
    case super(id) do
      [] -> nil
      [stop] -> stop
    end
  end

  def match(matcher, index, opts \\ []) do
    opts = Keyword.put_new(opts, :order_by, {:sort_order, :asc})
    super(matcher, index, opts)
  end
end
