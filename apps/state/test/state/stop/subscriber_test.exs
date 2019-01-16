defmodule State.Stop.SubscriberTest do
  @moduledoc false
  use ExUnit.Case
  import State.Stop.Subscriber

  describe "after a restart" do
    setup do
      # only put the stop into the cache, to simulate the worker not
      # receiving the information on startup
      State.Stop.Cache.new_state([
        %Model.Stop{latitude: 42.0, longitude: -71.0}
      ])

      :ok
    end

    test "ensures the workers have the right state" do
      Events.subscribe({:new_state, State.Stop})

      subscriber_pid =
        State.Stop
        |> Supervisor.which_children()
        |> Enum.find_value(fn {name, pid, _, _} ->
          if name == State.Stop.Subscriber, do: pid
        end)

      stop(subscriber_pid)

      # wait for the new_state event
      receive do
        {:event, _, _, _} -> :ok
      end

      # restarts subscriber, should pass state to the workers as well
      assert [_] = State.Stop.Worker.around(1, 42.0, -71.0)
    end
  end
end
