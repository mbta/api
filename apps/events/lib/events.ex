defmodule Events do
  @moduledoc """
  A simple wrapper around gproc for event pub/sub.

  Example:

      iex> Events.subscribe(:name, :argument)
      :ok
      iex> Events.publish(:name, :data)
      :ok
      iex> receive do
      ...>   x -> x
      ...> end
      {:event, :name, :data, :argument}

  """

  @type name :: any

  @doc """
  Subscribes the process to the given event.  Whenever the event is triggered,
  the process will receive a message tuple:

      {:event, <event name>, <event data>, <argument from subscribe>}

  """
  @spec subscribe(name, any) :: :ok
  def subscribe(name, argument \\ nil) do
    {:ok, _} = Registry.register(Events.Registry, name, argument)
    :ok
  end

  @doc """
  Publishes an event to any subscribers.
  """
  @spec publish(name, any) :: :ok
  def publish(name, data) do
    Registry.dispatch(Events.Registry, name, fn entries ->
      for {pid, argument} <- entries do
        send(pid, {:event, name, data, argument})
      end
    end)
  end
end
