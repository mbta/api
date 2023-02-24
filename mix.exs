defmodule ApiUmbrella.Mixfile do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      aliases: aliases(),
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_add_deps: :app_tree,
        flags: [
          :unmatched_returns
        ],
        ignore_warnings: ".dialyzer.ignore-warnings"
      ],
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/mbta/api",
      test_coverage: [tool: LcovEx],
      default_release: :api_web,
      releases: [
        api_web: [
          applications: [
            runtime_tools: :permanent,
            alb_monitor: :permanent,
            api_web: :permanent,
            api_accounts: :permanent,
            events: :permanent,
            fetch: :permanent,
            health: :permanent,
            model: :permanent,
            parse: :permanent,
            state: :permanent,
            state_mediator: :permanent
          ],
          version: "0.1.0"
        ]
      ]
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
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:lcov_ex, "~> 0.2", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.0", only: [:dev], runtime: false},
      # Generate docs with `mix docs`
      {:ex_doc, "~> 0.20", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs, do: [extras: extras()]

  defp extras do
    [
      "README.md": [filename: "readme", title: "API"],
      "apps/api_accounts/README.md": [filename: "api_accounts-readme", title: "API Accounts"],
      "apps/state_mediator/README.md": [
        filename: "state_mediator-readme",
        title: "State Mediator"
      ]
    ]
  end
end
