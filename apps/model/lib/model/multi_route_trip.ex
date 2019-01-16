defmodule Model.MultiRouteTrip do
  @moduledoc """
  `Model.Trip`s that span more than one `Model.Route`

  ## The train on two lines

  At 6:55pm on weekdays train 221 leaves the MBTA's North Station. It serves
  five stops on the Lowell Line, then uses a special track that connects the
  Lowell Line to the Haverhill Line, and serves five stops on the Haverhill
  Line. As such the MBTA publishes it on both the Lowell Line schedule and the
  Haverhill Line schedule. In GTFS it's marked as a Haverhill Line trip, with no
  indication that it should also appear on a presentation of the Lowell Line's
  schedule, or that the five Lowell Line stops it serves should not be
  considered part of the Haverhill Line.

  ## The hybrid bus route

  On weekdays the MBTA operates bus routes 62 and 76. On Saturday there is not
  enough demand for either but there is enough demand for one route that
  combines them, so we run buses on "route 62/76," which incorporates many of
  the stops on each route but all of the stops on neither. In this case the
  destination sign on the buses reads "62/76." We currently represent this as
  its own route in GTFS, with no data to indicate that a customer looking for a
  route 62 schedule or a route 76 schedule should be shown this route, or that
  "route 62/76" should be excluded from a list of MBTA bus services as
  redundant.
  """

  use Recordable, ~w(added_route_id trip_id)a

  @typedoc """
    * `added_route_id` - The `Model.Route.t` to add to `Model.Trip.id` with
       `id` `:trip_id`.
    * `trip_id` - The `Model.Trip.id` of the `Model.Trip` with the additional
      route with `Model.Route.id` `:added_route_id`.
  """
  @type t :: %__MODULE__{
          added_route_id: Model.Route.id(),
          trip_id: Model.Trip.id()
        }
end
