defmodule StateMediator do
  @moduledoc false
  use Application

  require Logger

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    crowding_source = app_value(:commuter_rail_crowding, :source)

    children =
      children(Application.get_env(:state_mediator, :start)) ++
        crowding_children(
          app_value(:commuter_rail_crowding, :enabled) == "true",
          crowding_source
        )

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

  @spec crowding_children(boolean(), String.t()) :: [
          :supervisor.child_spec() | {module(), term()} | module()
        ]
  defp crowding_children(true, "s3") do
    Logger.info("#{__MODULE__} CR_CROWDING_ENABLED=true, source=s3")

    [
      {
        StateMediator.S3Mediator,
        [
          spec_id: :cr_s3_crowding_mediator,
          bucket_arn: app_value(:commuter_rail_crowding, :s3_bucket),
          object: app_value(:commuter_rail_crowding, :s3_object),
          spec_id: :s3_mediator,
          interval: 5 * 60 * 1_000,
          sync_timeout: 30_000,
          state: State.CommuterRailOccupancy
        ]
      }
    ]
  end

  defp crowding_children(true, "firebase") do
    Logger.info("#{__MODULE__} CR_CROWDING_ENABLED=true, source=firebase")

    credentials = :commuter_rail_crowding |> app_value(:firebase_credentials) |> Jason.decode!()

    scopes = [
      "https://www.googleapis.com/auth/firebase.database",
      "https://www.googleapis.com/auth/userinfo.email"
    ]

    source = {:service_account, credentials, scopes: scopes}
    base_url = app_value(:commuter_rail_crowding, :firebase_url)

    [
      {Goth, [name: StateMediator.Goth, source: source]},
      {
        StateMediator.Mediator,
        [
          spec_id: :cr_crowding_mediator,
          state: State.CommuterRailOccupancy,
          url: {StateMediator.Firebase, :url, [StateMediator.Goth, base_url]},
          sync_timeout: 30_000,
          interval: 5 * 60 * 1_000,
          opts: [timeout: 10_000]
        ]
      }
    ]
  end

  defp crowding_children(false, _) do
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
