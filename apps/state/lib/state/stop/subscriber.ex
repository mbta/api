defmodule State.Stop.Subscriber do
  @moduledoc """
  Subscribes to `{:fetch, "stops.txt"}` events and uses it to reload state in `State.Stop`.
  """
  use Events.Server

  def start_link do
    GenServer.start_link(__MODULE__, nil)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  @impl Events.Server
  def handle_event({:fetch, "stops.txt"}, body, _, state) do
    :ok =
      body
      |> Parse.Stops.parse()
      |> State.Stop.new_state()

    {:noreply, state, :hibernate}
  end

  @impl GenServer
  def init(nil) do
    :ok = subscribe({:fetch, "stops.txt"})

    if State.Stop.size() > 0 do
      # if we crashed and restarted, ensure that all the workers also have
      # the correct state
      State.Stop.new_state(State.Stop.all())
    end

    {:ok, nil}
  end
end
