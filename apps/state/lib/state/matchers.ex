defmodule State.Matchers do
  @moduledoc """
  Helpers for building common matchers for querying in ETS.
  """

  @type stop_sequence_matcher ::
          %{position: :last | :first}
          | %{stop_sequence: integer}

  @doc """
  Generates a matcher for a direction_id.

      iex> State.Matchers.direction_id(1)
      %{direction_id: 1}

      iex> State.Matchers.direction_id(nil)
      %{}

      iex> State.Matchers.direction_id(4)
      %{}

      iex> State.Matchers.direction_id("0")
      %{}

  """
  @spec direction_id(0 | 1 | any) :: %{optional(:direction_id) => 0 | 1}
  def direction_id(direction_id) when direction_id in [0, 1] do
    %{direction_id: direction_id}
  end

  def direction_id(_), do: %{}

  @doc """
  Generates a matcher for a stop sequence.

      iex> State.Matchers.stop_sequence(:first)
      %{position: :first}

      iex> State.Matchers.stop_sequence(:last)
      %{position: :last}

      iex> State.Matchers.stop_sequence(5)
      %{stop_sequence: 5}

      iex> State.Matchers.stop_sequence("5")
      %{}
  """
  @spec stop_sequence(:first | :last | integer | any) :: stop_sequence_matcher | %{}
  def stop_sequence(position) when position in [:first, :last] do
    %{position: position}
  end

  def stop_sequence(stop) when is_integer(stop) do
    %{stop_sequence: stop}
  end

  def stop_sequence(_), do: %{}
end
