defmodule Events.Server do
  @moduledoc """
  Redirect `{:event, name, data, argument}` messages sent to a `GenServer` to a
  `handle_event(name, data, argument, state)` callback.
  """

  @callback handle_event(name :: term, data :: term, argument :: term, state :: term) ::
              {:noreply, new_state}
              | {:noreply, new_state, timeout | :hibernate}
              | {:stop, reason :: term, new_state}
            when new_state: term

  defmacro __using__(_) do
    quote location: :keep do
      use GenServer
      import Events

      @behaviour Events.Server

      @impl GenServer
      def handle_info({:event, name, data, argument}, state) do
        handle_event(name, data, argument, state)
      end

      def handle_info(_, state) do
        {:noreply, state}
      end

      defoverridable handle_info: 2
    end
  end
end
