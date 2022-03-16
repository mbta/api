defmodule ApiAccounts.Application do
  @moduledoc false
  use Application
  require Logger

  def start(_type, _args) do
    _ =
      if Application.get_env(:api_accounts, :migrate_on_start) do
        ApiAccounts.Dynamo.migrate()
      end

    Supervisor.start_link(
      [
        :hackney_pool.child_spec(:ex_aws_pool, []),
        ApiAccounts.Keys,
        {Task,
         fn ->
           Logger.info(
             "delete_tenable_users, beginning deletion of accounts matching 'wasscan*@tenable.com*'"
           )

           ApiAccounts.delete_tenable_users()

           Logger.info(
             "delete_tenable_users, finished deletion of accounts matching 'wasscan*@tenable.com*'"
           )
         end}
      ],
      strategy: :one_for_one,
      name: ApiAccounts.Supervisor
    )
  end
end
