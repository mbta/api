defmodule State.Stop.ListTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  alias Model.Stop
  alias State.Stop.List, as: StopList

  test "around searches around a geo point" do
    stop = %Stop{id: "1", name: "stop", latitude: 1, longitude: -2}
    list = StopList.new([stop])

    assert StopList.around(list, 1.001, -2.002) == ["1"]
    assert StopList.around(list, -1.001, 2.002) == []
    assert StopList.around(list, 1.001, -2.002, 0.001) == []
  end

  property "does not crash when provided stops" do
    check all(stops <- list_of(stop())) do
      StopList.new(stops)
    end
  end

  defp stop do
    # generate stops, some of which don't have a location
    gen all(
          id <- string(:ascii),
          {latitude, longitude} <- one_of([tuple({float(), float()}), constant({nil, nil})])
        ) do
      %Stop{id: id, latitude: latitude, longitude: longitude}
    end
  end
end
