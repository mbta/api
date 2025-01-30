defmodule StateMediator do
  @moduledoc false
  use Application

  require Logger

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    children =
      children(Application.get_env(:state_mediator, :start)) ++
        crowding_children(app_value(:commuter_rail_crowding, :enabled) == "true")

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [
      strategy: :one_for_one,
      name: StateMediator.Supervisor,
      max_restarts: length(children),
      max_seconds: 60
    ]

    Supervisor.start_link(children, opts)
  end

  defp children(true) do
    [
      {
        StateMediator.Mediator,
        [
          spec_id: :prediction_mediator,
          state: State.Prediction,
          url: source_url(State.Prediction),
          opts: [timeout: 10_000],
          sync_timeout: 30_000,
          interval: 10_000
        ]
      },
      vehicle_mediator_child(app_value(State.Vehicle, :broker), source_url(State.Vehicle)),
      {
        StateMediator.Mediator,
        [
          spec_id: :gtfs_mediator,
          state: GtfsDecompress,
          url: app_value(Realtime, :gtfs_url),
          opts: [timeout: 60_000],
          sync_timeout: 60_000
        ]
      },
      {
        StateMediator.Mediator,
        [
          spec_id: :alert_mediator,
          state: State.Alert,
          url: app_value(Realtime, :alert_url),
          sync_timeout: 30_000,
          interval: 10_000,
          opts: [timeout: 10_000]
        ]
      }
    ]
  end

  defp children(false) do
    []
  end

  defp vehicle_mediator_child(no_broker, url) when no_broker in ["", nil] do
    {
      StateMediator.Mediator,
      [
        spec_id: :vehicle_mediator,
        state: State.Vehicle,
        url: url,
        opts: [timeout: 10_000],
        sync_timeout: 30_000,
        interval: 1_000
      ]
    }
  end

  defp vehicle_mediator_child(broker, _url) do
    {
      StateMediator.MqttMediator,
      [
        spec_id: :vehicle_mediator,
        state: State.Vehicle,
        url: broker,
        topic: app_value(State.Vehicle, :topic),
        username: app_value(State.Vehicle, :username),
        password: fn -> app_value(State.Vehicle, :password) end,
        sync_timeout: 30_000
      ]
    }
  end

  @spec crowding_children(boolean()) :: [:supervisor.child_spec() | {module(), term()} | module()]
  defp crowding_children(true) do
    Logger.info("#{__MODULE__} CR_CROWDING_ENABLED=true")

    [
      {
        StateMediator.S3Mediator,
        [
          spec_id: :cr_s3_crowding_mediator,
          bucket_arn: "mbta-gtfs-commuter-rail-staging",
          object: "crowding-trends.json",
          spec_id: :s3_mediator,
          interval: 5 * 60 * 1_000,
          sync_timeout: 30_000,
          state: State.CommuterRailOccupancy
        ]
      }
    ]
  end

  defp crowding_children(false) do
    Logger.info("#{__MODULE__} CR_CROWDING_ENABLED=false")
    []
  end

  @doc false
  def source_url(mod) do
    case Application.get_env(:state_mediator, mod)[:source] do
      source when is_binary(source) -> source
      {:system, env_var, default} -> System.get_env(env_var) || default
    end
  end

  @doc false
  def app_value(group, key) do
    case Application.get_env(:state_mediator, group)[key] do
      {:system, env_var} ->
        System.get_env(env_var)

      {:system, env_var, default} ->
        System.get_env(env_var) || default

      value when is_binary(value) ->
        value
    end
  end
end
