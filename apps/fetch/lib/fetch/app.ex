defmodule Fetch.App do
  @moduledoc """

  Application for the various fetching servers. If configured with a
  `test: true` key, then does not start the fetchers.

  """
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    opts = Application.fetch_env!(:fetch, Fetch)

    children = [
      {Registry, keys: :unique, name: Fetch.Registry},
      supervisor(Fetch, [opts])
    ]

    opts = [strategy: :one_for_one, name: Fetch.App]
    Supervisor.start_link(children, opts)
  end
end
