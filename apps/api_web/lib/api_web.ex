defmodule ApiWeb do
  @moduledoc """
  The web API for the project
  """

  require Logger
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  # no cover
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    runtime_config!()

    # no cover
    children = [
      # Start the endpoint when the application starts
      worker(ApiWeb.RateLimiter, []),
      worker(RequestTrack, [[name: ApiWeb.RequestTrack]]),
      supervisor(ApiWeb.EventStream.Supervisor, []),
      supervisor(ApiWeb.Endpoint, []),
      worker(ApiWeb.EventStream.Canary, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ApiWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def runtime_config! do
    # pulls some configuration from the environment
    case System.get_env("LOG_LEVEL") do
      "debug" ->
        Logger.configure(level: :debug)

      _ ->
        :ok
    end
  end

  @doc """
  Fetches a configuration value and raises if missing.

  ## Examples

      iex> ApiWeb.config(:rate_limiter, :clear_interval)
      100
  """
  def config(root_key, sub_key) do
    root_key
    |> config()
    |> Keyword.fetch(sub_key)
    |> case do
      {:ok, val} ->
        val

      :error ->
        raise """
        missing :api_web mix configuration for key #{sub_key}
        """
    end
  end

  def config(root_key) do
    Application.fetch_env!(:api_web, root_key)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Expose swagger path in a way that will be valid when tests are run from
  # umbrella root AND apps/api
  def swagger_path, do: Application.app_dir(:api_web, "priv/static/swagger.json")
end
