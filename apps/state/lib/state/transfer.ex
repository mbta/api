defmodule State.Transfer do
  @moduledoc """

  Stores and indexes `Model.Transfer.t` from `transfers.txt`

  """

  use State.Server,
    fetched_filename: "transfers.txt",
    recordable: Model.Transfer,
    indicies: [:from_stop_id],
    parser: Parse.Transfers

  def recommended_transfers_from(stop_id) when is_binary(stop_id) do
    stop_id
    |> by_from_stop_id()
    |> Enum.filter(&(&1.transfer_type == 0))
    |> Enum.map(& &1.to_stop_id)
    |> State.Stop.by_ids()
  end

  def recommended_transfers_from(nil) do
    []
  end
end
