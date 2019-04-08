defmodule State.TransferTest do
  use ExUnit.Case
  import State.Transfer
  alias Model.{Transfer, Stop}

  setup do
    State.Transfer.new_state([])

    :ok
  end

  test "it can add a transfer and query it" do
    transfer = %Transfer{from_stop_id: "1", to_stop_id: "2", transfer_type: 0}
    State.Transfer.new_state([transfer])

    assert State.Transfer.by_from_stop_id("1") == [transfer]
    assert State.Transfer.by_from_stop_id("2") == []
  end

  test "recommended_transfers_from/1" do
    from = %Stop{id: "1"}
    to = %Stop{id: "2"}
    State.Stop.new_state([from, to])

    transfer = %Transfer{from_stop_id: "1", to_stop_id: "2", transfer_type: 0}
    State.Transfer.new_state([transfer])

    assert recommended_transfers_from(from.id) == [to]

    transfer = %Transfer{from_stop_id: "1", to_stop_id: "2", transfer_type: 2}
    State.Transfer.new_state([transfer])

    assert recommended_transfers_from(from.id) == []
  end

  test "last_updated/0" do
    assert %DateTime{} = State.Transfer.last_updated()
  end
end
