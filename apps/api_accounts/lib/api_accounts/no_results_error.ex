defmodule ApiAccounts.NoResultsError do
  @moduledoc """
  Error representing when no results were found when they were expected.
  """

  defexception [:message]

  @doc """
  Callback implementation for `Exception.exception/1`.
  """
  def exception(message) do
    %__MODULE__{message: message}
  end
end
