defmodule State.FacilityTest do
  @moduledoc false
  use ExUnit.Case

  import State.Facility
  alias Model.Facility

  setup do
    new_state([
      %Facility{
        id: "6",
        type: "ESCALATOR",
        stop_id: "place-alfcl"
      },
      %Facility{
        id: "701",
        type: "ELEVATOR",
        stop_id: "place-qnctr"
      },
      %Facility{
        id: "3",
        type: "ELEVATOR",
        stop_id: "place-alfcl"
      }
    ])

    :ok
  end

  describe "by_id/1" do
    test "returns an escalator" do
      escalator = by_id("6")
      assert escalator.id == "6"
      assert escalator.type == "ESCALATOR"
    end

    test "returns an elevator" do
      elevator = by_id("701")
      assert elevator.id == "701"
      assert elevator.type == "ELEVATOR"
    end

    test "returns nil for an invalid id" do
      assert by_id("") == nil
    end
  end

  describe "all/1" do
    test "returns all facilities" do
      assert [%Model.Facility{}, _ | _] = all()
    end

    test "returns limited results, with and without offset" do
      {data, _} = all(limit: 1)
      assert [%Model.Facility{} = facility] = data
      {data, _} = all(limit: 2)
      assert [^facility, %Model.Facility{} = facility2] = data
      {data, _} = all(offset: 1, limit: 1)
      assert [^facility2] = data
    end
  end

  describe "filter_by/1" do
    test "lists all facilities when no filters are given" do
      sorted_results =
        %{}
        |> State.Facility.filter_by()
        |> Enum.sort_by(& &1.id)

      assert sorted_results == [by_id("3"), by_id("6"), by_id("701")]
    end

    test "filters by stop_id" do
      sorted_results =
        %{stop_id: ~w(place-alfcl)}
        |> State.Facility.filter_by()
        |> Enum.sort_by(& &1.id)

      assert sorted_results == [by_id("3"), by_id("6")]
    end

    test "filters by type" do
      sorted_results =
        %{type: ~w(ELEVATOR)}
        |> State.Facility.filter_by()
        |> Enum.sort_by(& &1.id)

      assert sorted_results == [by_id("3"), by_id("701")]
    end

    test "filters by stop_id and type" do
      sorted_results =
        %{stop_id: ~w(place-alfcl), type: ~w(ELEVATOR)}
        |> State.Facility.filter_by()
        |> Enum.sort_by(& &1.id)

      assert sorted_results == [by_id("3")]
    end
  end
end
