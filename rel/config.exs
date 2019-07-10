use Distillery.Releases.Config,
    # This sets the default release built by `mix release`
    default_release: :api_web,
    # This sets the default environment used by `mix release`
    default_environment: :prod

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/configuration.html

# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: "NODE_COOKIE" |> System.get_env |> Kernel.||("prod_cookie") |> String.to_atom
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :api_web do
  set version: "0.1.0"
  set vm_args: "rel/vm.args"
  set applications: [
    :runtime_tools,
    api_web: :permanent,
    api_accounts: :permanent,
    events: :permanent,
    fetch: :permanent,
    health: :permanent,
    model: :permanent,
    parse: :permanent,
    state: :permanent,
    state_mediator: :permanent
  ]
end
