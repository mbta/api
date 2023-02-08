defmodule Parse.Mixfile do
  use Mix.Project

  def project do
    [
      app: :parse,
      aliases: aliases(),
      build_embedded: Mix.env() == :prod,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps: deps(),
      deps_path: "../../deps",
      elixir: "~> 1.2",
      lockfile: "../../mix.lock",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: LcovEx],
      version: "0.0.1"
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      extra_applications: [:logger]
    ]
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
      {:ex_csv, "~> 0.1.4"},
      {:exprotobuf, "~> 1.2"},
      {:gpb, "< 4.20.0"},
      {:timex, "~> 3.2"},
      {:jason, "~> 1.0"},
      {:model, in_umbrella: true},
      {:polyline, "~> 1.0"},
      {:fast_local_datetime, "~> 1.0"},
      {:nimble_parsec, "~> 1.1"}
    ]
  end
end
