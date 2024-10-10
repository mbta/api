defmodule State.AgencyTest do
  use ExUnit.Case
  alias Model.Agency

  setup do
    State.Agency.new_state([])
  end

  test "returns nil for unknown agency" do
    assert State.Agency.by_id("1") == nil
  end

  test "it can add an agency and query it" do
    agency = %Agency{
      id: "1",
      agency_name: "Made-Up Transit Agency"
    }

    State.Agency.new_state([agency])

    assert State.Agency.by_id("1") == agency
  end
end
