defmodule Events.Gather do
  @moduledoc """
  Gathers multiple event `keys` so that only when all `keys` are `received` is `callback` called, so that event
  callbacks don't need to handle subsets of events.
  """

  defstruct [:keys, :received, :callback]

  def new(keys, callback) when is_list(keys) and is_function(callback, 1) do
    %__MODULE__{keys: Enum.sort(keys), received: %{}, callback: callback}
  end

  def update(%__MODULE__{keys: keys, received: received, callback: callback} = state, key, value) do
    received = Map.put(received, key, value)

    if received |> Map.keys() |> Enum.sort() == keys do
      callback.(received)
    end

    %{state | received: received}
  end
end
