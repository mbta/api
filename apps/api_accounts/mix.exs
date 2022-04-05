defmodule ApiAccounts.Mixfile do
  use Mix.Project

  def project do
    [app: :api_accounts,
     aliases: aliases(),
     build_embedded: Mix.env == :prod,
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps: deps(),
     deps_path: "../../deps",
     docs: docs(),
     elixir: "~> 1.4",
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
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {ApiAccounts.Application, []}]
  end

  defp aliases do
    [compile: ["compile --warnings-as-errors"]]
  end

  def elixirc_paths(:test), do: ["lib", "test/support"]
  def elixirc_paths(_), do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:my_app, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
     {:fetch, in_umbrella: true},
     {:ex_aws, "~> 2.0"},
     {:ex_aws_dynamo, "~> 4.0"},
     {:jason, "~> 1.0"},
     {:comeonin, "~> 5.1"},
     {:bcrypt_elixir, "~> 3.0"},
     {:uuid, "~> 1.1"},
     {:bamboo, "~> 1.0"},
     {:bamboo_ses, "~> 0.1.0"}]
  end

  defp docs, do: [extras: extras()]

  # Extra files for docs and package (if ever turned into a hex.pm package)
  defp extras, do: ~w(README.md)
end
