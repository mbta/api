# Used by "mix format"
[
  inputs: [
    "{mix,.formatter}.exs",
    "apps/*/{config,lib,test}/**/*.{heex,ex,exs}",
    "apps/*/mix.exs"
  ],
  import_deps: [:phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  rename_deprecated_at: "1.14.3"
]
