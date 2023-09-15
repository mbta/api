defmodule StateMediator.MqttMediator.Handler do
  @moduledoc """
  EmqttFailover.ConnectionHandler implementation which sends the data to the provided state module.
  """
  require Logger

  use EmqttFailover.ConnectionHandler

  @enforce_keys [
    :module,
    :topic,
    :timeout
  ]
  defstruct @enforce_keys

  @impl EmqttFailover.ConnectionHandler
  def init(opts) do
    state = struct!(__MODULE__, opts)
    {:ok, state}
  end

  @impl EmqttFailover.ConnectionHandler
  def handle_connected(state) do
    Logger.info("StateMediator.MqttMediator subscribed topic=#{state.topic}")
    {:ok, [state.topic], state}
  end

  @impl EmqttFailover.ConnectionHandler
  def handle_message(message, state) do
    debug_time("#{state.module} new state", fn ->
      state.module.new_state(message.payload, state.timeout)
    end)

    {:ok, state}
  end

  defp debug_time(description, func) do
    State.Logger.debug_time(func, fn milliseconds ->
      "StateMediator.MqttMediator #{description} took #{milliseconds}ms"
    end)
  end
end
