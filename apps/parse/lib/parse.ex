defmodule Parse do
  @moduledoc """

  Behaviour for all our parsers.  They should take a binary and return an
  Enumerable of whatever they're parsing.

  """
  @callback parse(binary) :: Enumerable.t()
end
