defmodule StateMediator.MqttMediator do
  @moduledoc """

  MqttMediator is responsible for subscribing to a topic in an MQTT broker and
  sending messages to the state module.

  """
  defstruct [
    :module,
    :configs,
    :topic,
    :client,
    :sync_timeout
  ]

  @opaque t :: %__MODULE__{
            module: module,
            configs: [EmqttFailover.Config.t(), ...],
            topic: String.t(),
            client: nil | pid(),
            sync_timeout: pos_integer
          }

  use GenServer
  require Logger

  def child_spec(opts) do
    {spec_id, opts} = Keyword.pop!(opts, :spec_id)

    %{
      id: spec_id,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec start_link(Keyword.t()) :: {:ok, GenServer.server()}
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @spec stop(pid) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @impl GenServer
  def init(options) do
    state_module = Keyword.fetch!(options, :state)

    url = Keyword.fetch!(options, :url)
    configs = configs_from_url(url, options)

    topic = Keyword.fetch!(options, :topic)

    sync_timeout = options |> Keyword.get(:sync_timeout, 5000)

    {:ok,
     %__MODULE__{
       module: state_module,
       configs: configs,
       topic: topic,
       sync_timeout: sync_timeout
     }, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, state) do
    {:ok, client} =
      EmqttFailover.Connection.start_link(
        client_id: EmqttFailover.client_id(prefix: "api"),
        configs: state.configs,
        handler:
          {__MODULE__.Handler,
           module: state.module, topic: state.topic, timeout: state.sync_timeout}
      )

    state = %{state | client: client}
    {:noreply, state}
  end

  defp configs_from_url(url, opts) do
    password_opts =
      case opts[:password] do
        nil -> [[]]
        [""] -> [[]]
        passwords -> for password <- String.split(passwords, " "), do: [password: password]
      end

    username_opt =
      if username = opts[:username] do
        [username: username]
      else
        []
      end

    for url <- String.split(url, " "),
        password_opt <- password_opts do
      EmqttFailover.Config.from_url(
        url,
        username_opt ++ password_opt
      )
    end
  end
end
