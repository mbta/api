defmodule State.Transfer do
  @moduledoc """

  Stores and indexes `Model.Transfer.t` from `transfers.txt`

  """

  use State.Server,
    fetched_filename: "transfers.txt",
    recordable: Model.Transfer,
    indices: [:from_stop_id],
    parser: Parse.Transfers

  def recommended_transfers_from(stop_id) do
    [%{from_stop_id: stop_id, transfer_type: 0}]
    |> select(:from_stop_id)
    |> Enum.map(& &1.to_stop_id)
    |> State.Stop.by_ids()
  end
end
