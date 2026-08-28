defmodule State.Transfer do
  @moduledoc """
  Maintains the current state of transfers.
  """

  use State.Server,
    fetched_filename: "transfers.txt",
    parser: Parse.Transfers,
    recordable: Model.Transfer
end
