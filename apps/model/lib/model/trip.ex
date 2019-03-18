defmodule Model.Trip do
  @moduledoc """
  Trip represents the journey a vehicle takes through a set of stops.
  """

  use Recordable, [
    :id,
    :service_id,
    :route_id,
    :headsign,
    :name,
    :direction_id,
    :block_id,
    :shape_id,
    :wheelchair_accessible,
    :alternate_route,
    :route_type,
    :bikes_allowed,
    :route_pattern_id
  ]

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id,
          service_id: Model.Service.id() | nil,
          route_id: Model.Route.id(),
          route_type: Model.Route.route_type() | nil,
          shape_id: Model.Shape.id() | nil,
          headsign: String.t(),
          name: String.t(),
          direction_id: Model.Direction.id(),
          # not used right now,
          block_id: String.t() | nil,
          wheelchair_accessible: 0..2,
          alternate_route: boolean | nil,
          bikes_allowed: 0..2,
          route_pattern_id: Model.RoutePattern.id()
        }

  @doc """

  A Trip is a primary if either

  1) it has no alternate route (alernate_route: nil)
  2) it isn't the alternate route trip (alernate_route: false)

  """
  @spec primary?(t) :: boolean
  def primary?(trip)
  def primary?(%__MODULE__{alternate_route: true}), do: false
  def primary?(%__MODULE__{}), do: true
end
