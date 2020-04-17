defmodule Parse.Helpers do
  @moduledoc "Helper functions for parsing"

  @doc "Copies a binary, otherwise returns the term unchanged"
  @spec copy(term) :: term
  def copy(binary) when is_binary(binary) do
    :binary.copy(binary)
  end

  def copy(other), do: other

  @doc "Copies a binary, but treats the empty string as a nil value"
  @spec optional_copy(term) :: term
  def optional_copy("") do
    # empty string is a default value and should be treated as a not-provided
    # value
    nil
  end

  def optional_copy(value) do
    copy(value)
  end
end
