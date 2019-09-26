defmodule State.Helpers do
  @moduledoc """
  Helper functions for State modules.
  """
  alias Model.Trip

  @doc """
  Returns true if the given Model.Trip is on a hidden (negative priority) shape.
  """
  def trip_on_hidden_shape?(%{shape_id: shape_id}) do
    case State.Shape.by_primary_id(shape_id) do
      %{priority: priority} when priority < 0 ->
        true

      _ ->
        false
    end
  end

  @doc """
  Returns true if the given Model.Trip shouldn't be considered (by default) as having stops on the route.

  We ignore negative priority shapes, as well as alternate route trips.
  """
  def ignore_trip_for_route?(%Trip{route_type: type}) when is_integer(type), do: true
  def ignore_trip_for_route?(%Trip{alternate_route: bool}) when is_boolean(bool), do: true
  def ignore_trip_for_route?(%Trip{} = trip), do: trip_on_hidden_shape?(trip)

  @doc """
  Returns true if the given Model.Trip shouldn't be considered (by default) as being part of the route based on the pattern.

  We ignore as alternate route trips, as well as very-atypical patterns. This
  can be overridden with :ignore_overrides in the configuration.
  """
  @spec ignore_trip_route_pattern?(Model.Trip.t()) :: boolean
  def ignore_trip_route_pattern?(trip)

  for {route_pattern_id, ignore?} <-
        Application.get_env(:state, :route_pattern)[:ignore_overrides] do
    def ignore_trip_route_pattern?(%Trip{route_pattern_id: unquote(route_pattern_id)}),
      do: unquote(ignore?)
  end

  def ignore_trip_route_pattern?(%Trip{route_type: int}) when is_integer(int), do: true
  def ignore_trip_route_pattern?(%Trip{alternate_route: bool}) when is_boolean(bool), do: true

  def ignore_trip_route_pattern?(%Trip{route_pattern_id: route_pattern_id})
      when is_binary(route_pattern_id) do
    case State.RoutePattern.by_id(route_pattern_id) do
      %{typicality: typicality} when typicality < 4 ->
        false

      _ ->
        true
    end
  end

  def ignore_trip_route_pattern?(%Trip{route_pattern_id: nil}), do: true

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
