defmodule ALBMonitor.Mixfile do
  use Mix.Project

  def project do
    [app: :alb_monitor,
     aliases: aliases(),
     build_embedded: Mix.env == :prod,
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps: deps(),
     deps_path: "../../deps",
     elixir: "~> 1.10",
     elixirc_paths: elixirc_paths(Mix.env),
     lockfile: "../../mix.lock",
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: LcovEx],
     version: "0.1.0"]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: [:logger],
     mod: {ALBMonitor, []}]
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
      {:ex_aws, "~> 2.4"},
      {:ex_aws_elastic_load_balancing, "~> 2.0"},
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:mox, "~> 1.0", only: :test},
      {:sweet_xml, "~> 0.7"}
    ]
  end

  # Prevent compiler warnings about mock modules not being defined.
  # See https://hexdocs.pm/mox/Mox.html#module-compile-time-requirements
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_),     do: ["lib"]
end
