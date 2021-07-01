defmodule StateMediator do
  @moduledoc false
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    children = children(Application.get_env(:state_mediator, :start))

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
    import Supervisor.Spec, warn: false

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
      {
        StateMediator.Mediator,
        [
          spec_id: :vehicle_mediator,
          state: State.Vehicle,
          url: source_url(State.Vehicle),
          opts: [timeout: 10_000],
          sync_timeout: 30_000,
          interval: 1_000
        ]
      },
      {
        StateMediator.Mediator,
        [
          spec_id: :parking_mediator,
          state: State.Facility.Parking,
          url: source_url(State.Facility.Parking),
          opts: [timeout: 10_000],
          sync_timeout: 30_000,
          interval: 60_000
        ]
      },
      {
        StateMediator.Mediator,
        [
          spec_id: :gtfs_mediator,
          state: GtfsDecompress,
          url: app_value(:gtfs_url),
          opts: [timeout: 60_000],
          sync_timeout: 60_000
        ]
      },
      {
        StateMediator.Mediator,
        [
          spec_id: :alert_mediator,
          state: State.Alert,
          url: app_value(:alert_url),
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

  @doc false
  def source_url(mod) do
    case Application.get_env(:state_mediator, mod)[:source] do
      source when is_binary(source) -> source
      {:system, env_var, default} -> System.get_env(env_var) || default
    end
  end

  def app_value(key) do
    case Application.get_env(:state_mediator, Realtime)[key] do
      {:system, env_var} ->
        System.get_env(env_var)

      {:system, env_var, default} ->
        System.get_env(env_var) || default

      value when is_binary(value) ->
        value
    end
  end
end
