defmodule StateMediator.Mixfile do
  use Mix.Project

  def project do
    [
      app: :state_mediator,
      aliases: aliases(),
      build_embedded: Mix.env() == :prod,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps: deps(),
      deps_path: "../../deps",
      elixir: "~> 1.3",
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
    [extra_applications: [:logger], mod: {StateMediator, []}]
  end

  defp aliases do
    [compile: ["compile --warnings-as-errors"]]
  end

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
      {:events, in_umbrella: true},
      {:state, in_umbrella: true},
      {:fetch, in_umbrella: true},
      {:goth, "~> 1.3"},
      {:hackney, "~> 1.18"},
      {:timex, "~> 3.7"},
      {:emqtt_failover, git: "https://gitlab.com/paulswartz/emqtt_failover.git", tag: "v0.2"}
    ]
  end
end
