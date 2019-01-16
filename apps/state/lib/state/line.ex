defmodule State.Line do
  @moduledoc """

  Stores and indexes `Model.Line.t` from `lines.txt`.

  """
  use State.Server,
    fetched_filename: "lines.txt",
    recordable: Model.Line,
    indicies: [:id],
    parser: Parse.Line

  def by_id(id) do
    case super(id) do
      [] -> nil
      [line] -> line
    end
  end
end
