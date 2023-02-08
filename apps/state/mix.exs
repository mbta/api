defmodule State.Mixfile do
  use Mix.Project

  def project do
    [app: :state,
     aliases: aliases(),
     build_embedded: Mix.env == :prod,
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps: deps(),
     deps_path: "../../deps",
     elixir: "~> 1.2",
     elixirc_paths: elixirc_paths(Mix.env),
     lockfile: "../../mix.lock",
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: LcovEx],
     version: "0.0.1"]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: [:logger, :mnesia, :rstar],
     mod: {State, []}]
  end

  defp aliases do
    [compile: ["compile --warnings-as-errors"]]
  end

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
      {:rstar, github: 'armon/erl-rstar', app: false},
      {:timex, "~> 3.2"},
      {:fetch, in_umbrella: true},
      {:events, in_umbrella: true},
      {:model, in_umbrella: true},
      {:parse, in_umbrella: true},
      {:benchfella, "~> 0.0", only: [:dev, :test]},
      {:dialyxir, "~> 1.2.0", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 0.4", only: :test}
    ]
  end
end
