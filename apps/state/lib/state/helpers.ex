defmodule State.Helpers do
  @moduledoc """
  Helper functions for State modules.
  """
  alias Model.Trip

  @doc """
  Returns true if the given trip should, by default, "contribute" its stops to the set of stops
  considered to be "on" its route or route pattern.
  """
  @spec stops_on_route?(Model.Trip.t()) :: boolean
  def stops_on_route?(trip)

  # Allow for overriding the return value using the `:route_pattern_prefix_overrides` config
  for {route_pattern_id, include?} <-
        Application.compile_env(:state, :stops_on_route)[:route_pattern_prefix_overrides] do
    def stops_on_route?(%Trip{route_pattern_id: unquote(route_pattern_id) <> _}),
      do: unquote(include?)
  end

  # Ignore alternate route trips and trips with a trip-specific route type
  def stops_on_route?(%Trip{route_type: int}) when is_integer(int), do: false
  def stops_on_route?(%Trip{alternate_route: bool}) when is_boolean(bool), do: false

  # Ignore trips on atypical patterns
  def stops_on_route?(%Trip{route_pattern_id: route_pattern_id})
      when is_binary(route_pattern_id) do
    case State.RoutePattern.by_id(route_pattern_id) do
      %{typicality: typicality} when typicality < 4 ->
        true

      _ ->
        false
    end
  end

  # Ignore trips with no route pattern
  def stops_on_route?(%Trip{route_pattern_id: nil}), do: false

  @doc """
  As above, but makes the decision based on whether the trip has a "hidden" (negative priority)
  shape.
  """
  @spec stops_on_route_by_shape?(Model.Trip.t()) :: boolean
  def stops_on_route_by_shape?(%Trip{route_type: type}) when is_integer(type), do: false
  def stops_on_route_by_shape?(%Trip{alternate_route: bool}) when is_boolean(bool), do: false

  def stops_on_route_by_shape?(%{shape_id: shape_id}) do
    case State.Shape.by_primary_id(shape_id) do
      %{priority: priority} when priority < 0 ->
        false

      _ ->
        true
    end
  end

  @doc """
  Safely get the size of an ETS table

  If the table doesn't exist, we'll return a 0 size.
  """
  @spec safe_ets_size(:ets.tab()) :: non_neg_integer
  def safe_ets_size(table) do
    case :ets.info(table, :size) do
      :undefined ->
        0

      value when is_integer(value) ->
        value
    end
  end
end
