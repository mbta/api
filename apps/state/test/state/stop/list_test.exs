defmodule State.Stop.ListTest do
  use ExUnit.Case, async: true
  alias Model.Stop
  alias State.Stop.List, as: StopList

  test "around searches around a geo point" do
    stop = %Stop{id: "1", name: "stop", latitude: 1, longitude: -2}
    list = StopList.new([stop])

    assert StopList.around(list, 1.001, -2.002) == ["1"]
    assert StopList.around(list, -1.001, 2.002) == []
    assert StopList.around(list, 1.001, -2.002, 0.001) == []
  end
end
