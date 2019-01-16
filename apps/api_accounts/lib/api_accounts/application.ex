defmodule ApiAccounts.Application do
  @moduledoc false
  use Application
  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    _ =
      if Application.get_env(:api_accounts, :migrate_on_start) do
        ApiAccounts.Dynamo.migrate()
      end

    Supervisor.start_link(
      [
        worker(ApiAccounts.Keys, [])
      ],
      strategy: :one_for_one,
      name: ApiAccounts.Supervisor
    )
  end
end
