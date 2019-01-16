defmodule ApiUmbrella.Mixfile do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      aliases: aliases(),
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_deps: :transitive,
        flags: [
          :race_conditions,
          :unmatched_returns
        ],
        ignore_warnings: ".dialyzer.ignore-warnings"
      ],
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/mbta/api",
      test_coverage: [tool: ExCoveralls]
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
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps folder
  defp deps do
    # Static analysis and style checking
    [
      {:credo, ">= 0.0.0", only: [:dev, :test]},
      # Test coverage reporting on coveralls.io
      {:excoveralls, "~> 0.5", only: :test},
      # Generate docs with `mix docs`
      {:ex_doc, "~> 0.18.1", only: [:dev, :test]}
    ]
  end

  defp docs, do: [extras: extras()]

  defp extras do
    [
      "API.md": [filename: "api-endpoints", title: "API Endpoints"],
      "README.md": [filename: "readme", title: "API"],
      "apps/api_accounts/README.md": [filename: "api_accounts-readme", title: "API Accounts"],
      "apps/state_mediator/README.md": [
        filename: "state_mediator-readme",
        title: "State Mediator"
      ]
    ]
  end
end
