defmodule State.Transfer do
  @moduledoc """
  Maintains the current state of transfers.
  """

  use State.Server,
    indices: [:from_trip_id],
    fetched_filename: "transfers.txt",
    parser: Parse.Transfers,
    recordable: Model.Transfer

  @type filter_opts :: %{
          optional(:from_trip_ids) => [Model.Trip.id()]
        }

  @type transfer_search :: (-> [Model.Transfer.t()])

  @doc """
  Applies a filtered search on Transfers based on a map of filter values.

  The allowed filterable keys are:
    :from_trip_ids
  """
  @spec filter_by(filter_opts) :: [Model.Transfer.t()]
  def filter_by(%{from_trip_ids: trip_ids}) do
    by_from_trip_ids(trip_ids)
  end
end
