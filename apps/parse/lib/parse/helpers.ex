defmodule Parse.Helpers do
  @moduledoc "Helper functions for parsing"

  @doc "Copies a binary, otherwise returns the term unchanged"
  @spec copy(term) :: term
  def copy(binary) when is_binary(binary) do
    :binary.copy(binary)
  end

  def copy(other), do: other
end
