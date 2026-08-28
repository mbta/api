defmodule State.TransferTest do
  use ExUnit.Case

  alias Model.Transfer

  @transfer1 %Transfer{
    from_stop_id: "place-north",
    to_stop_id: "place-south",
    transfer_type: 0,
    from_trip_id: "trip-A",
    to_trip_id: "trip-B"
  }

  @transfer2 %Transfer{
    from_stop_id: "place-east",
    to_stop_id: "place-west",
    transfer_type: 2,
    min_transfer_time: 300,
    from_trip_id: "trip-C",
    to_trip_id: "trip-D"
  }

  @transfer3 %Transfer{
    from_stop_id: "place-north",
    to_stop_id: "place-east",
    transfer_type: 2,
    from_trip_id: nil,
    to_trip_id: nil
  }

  setup do
    State.Transfer.new_state([])
    :ok
  end

  test "returns empty list when no transfers are loaded" do
    assert State.Transfer.all() == []
  end

  test "loads and retrieves all transfers" do
    State.Transfer.new_state([@transfer1, @transfer2])
    assert length(State.Transfer.all()) == 2
  end

  describe "filter_by/1" do
    setup do
      State.Transfer.new_state([@transfer1, @transfer2, @transfer3])
      :ok
    end

    test "returns empty list when filters map is empty" do
      assert State.Transfer.filter_by(%{}) == []
    end

    test "filters by transfer types" do
      results = State.Transfer.filter_by(%{types: ["2"]})
      assert length(results) == 2
      assert Enum.all?(results, &(&1.transfer_type == 2))
    end

    test "filters by a single type that matches one record" do
      results = State.Transfer.filter_by(%{types: ["0"]})
      assert length(results) == 1
      assert hd(results).transfer_type == 0
    end

    test "filters by from_trip_ids" do
      results = State.Transfer.filter_by(%{from_trip_ids: ["trip-A"]})
      assert length(results) == 1
      assert hd(results).from_trip_id == "trip-A"
    end

    test "filters by multiple from_trip_ids" do
      results = State.Transfer.filter_by(%{from_trip_ids: ["trip-A", "trip-C"]})
      assert length(results) == 2
    end

    test "returns empty list when type matches nothing" do
      results = State.Transfer.filter_by(%{types: ["5"]})
      assert results == []
    end

    test "returns intersection when both types and from_trip_ids are provided" do
      results = State.Transfer.filter_by(%{types: ["2"], from_trip_ids: ["trip-C"]})
      assert length(results) == 1
      assert hd(results).from_trip_id == "trip-C"
      assert hd(results).transfer_type == 2
    end

    test "returns empty list when intersection is empty" do
      results = State.Transfer.filter_by(%{types: ["0"], from_trip_ids: ["trip-C"]})
      assert results == []
    end
  end
end
