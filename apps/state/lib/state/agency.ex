defmodule State.Agency do
  @moduledoc """
  Stores and indexes `Model.Agency.t` from `agency.txt`.
  """

  use State.Server,
    indices: [:id],
    fetched_filename: "agency.txt",
    parser: Parse.Agency,
    recordable: Model.Agency

  alias Model.Agency

  @spec by_id(Agency.id()) :: Agency.t() | nil
  def by_id(id) do
    case super(id) do
      [] -> nil
      [agency] -> agency
    end
  end
end
