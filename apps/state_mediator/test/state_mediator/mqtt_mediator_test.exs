defmodule StateMediator.MqttMediatorTest do
  use ExUnit.Case, async: true

  import StateMediator.MqttMediator

  defmodule StateModule do
    use Agent

    def start_link(opts) do
      parent = Keyword.fetch!(opts, :parent)
      Agent.start_link(fn -> parent end, name: __MODULE__)
    end

    def new_state(contents, timeout) do
      Agent.get(
        __MODULE__,
        fn parent ->
          send(parent, {:updated, contents})
          :ok
        end,
        timeout
      )
    catch
      :exit, reason ->
        {:error, reason}
    end
  end

  # @moduletag capture_log: true
  @opts [
    url: "mqtt://test.mosquitto.org/#{URI.encode_www_form("home/#")}",
    state: __MODULE__.StateModule
  ]

  describe "init/1" do
    test "continues with connect message" do
      assert {:ok, _, {:continue, :connect}} = init(@opts)
    end

    test "builds an initial state" do
      assert {:ok, state, _} = init(@opts)
      assert %StateMediator.MqttMediator{} = state
      assert state.module == @opts[:state]
      assert state.sync_timeout == 5_000
    end
  end

  describe "incoming messages" do
    setup do
      start_supervised!({__MODULE__.StateModule, parent: self()})

      :ok
    end

    test "are sent to the state module" do
      {:ok, _pid} = start_link(@opts)
      assert_receive {:updated, contents}, 5_000
      assert <<_::binary>> = contents
    end
  end
end
