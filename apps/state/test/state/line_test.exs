defmodule State.LineTest do
  use ExUnit.Case
  alias Model.Line

  setup do
    State.Line.new_state([])
    :ok
  end

  test "returns nil for unknown line" do
    assert State.Line.by_id("1") == nil
  end

  test "it can add a line and query it" do
    line = %Line{
      id: "1",
      short_name: "1st Line",
      long_name: "First Line",
      color: "00843D",
      text_color: "FFFFFF",
      sort_order: 1
    }

    State.Line.new_state([line])

    assert State.Line.by_id("1") == %Line{
             id: "1",
             short_name: "1st Line",
             long_name: "First Line",
             color: "00843D",
             text_color: "FFFFFF",
             sort_order: 1
           }
  end
end
