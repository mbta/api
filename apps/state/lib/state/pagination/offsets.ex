defmodule State.Pagination.Offsets do
  @moduledoc """
  Holds pagination offsets for the first, last, next, and previous pages.
  """

  defstruct [:next, :prev, :first, :last]

  @type t :: %__MODULE__{
          next: pos_integer | nil,
          prev: non_neg_integer | nil,
          first: 0,
          last: non_neg_integer
        }
end
