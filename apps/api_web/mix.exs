defmodule ApiWeb.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :api_web,
      aliases: aliases(),
      build_embedded: Mix.env() == :prod,
      build_path: "../../_build",
      compilers: [:phoenix] ++ Mix.compilers() ++ [:phoenix_swagger],
      config_path: "../../config/config.exs",
      deps: deps(),
      deps_path: "../../deps",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: LcovEx],
      version: "0.1.0"
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    extra_applications = [:logger, :phoenix_swagger | env_applications(Mix.env())]
    [mod: {ApiWeb, []}, extra_applications: extra_applications]
  end

  defp aliases do
    [compile: ["compile --warnings-as-errors"]]
  end

  defp env_applications(:prod) do
    [:sasl, :diskusage_logger]
  end

  defp env_applications(_) do
    []
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:phoenix, "~> 1.6.2"},
      {:phoenix_html, "~> 3.1"},
      {:phoenix_live_view, "~> 0.18.4"},
      {:ja_serializer, github: "mbta/ja_serializer", branch: "master"},
      {:timex, "~> 3.2"},
      {:corsica, "~> 1.1"},
      {:state_mediator, in_umbrella: true},
      {:health, in_umbrella: true},
      {:api_accounts, in_umbrella: true},
      {:memcachex, "~> 0.4"},
      {:ehmon, github: "mbta/ehmon", branch: "master", only: :prod},
      {:benchwarmer, "~> 0.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:logster, "~> 1.0"},
      {:phoenix_swagger, github: "mbta/phoenix_swagger", branch: "master"},
      {:ex_json_schema, "~> 0.6.2"},
      {:diskusage_logger, "~> 0.2.0", only: :prod},
      {:jason, "~> 1.0"},
      {:stream_data, "~> 0.4", only: :test},
      {:plug_cowboy, "~> 2.1"}
    ]
  end
end
