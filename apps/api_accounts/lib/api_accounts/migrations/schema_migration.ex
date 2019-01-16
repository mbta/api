defprotocol ApiAccounts.Migrations.SchemaMigration do
  @moduledoc """
  Protocol for migrating a DynamoDB item to different versions.
  """
  @fallback_to_any true

  def migrate(item, current_version, target_version)
end

defimpl ApiAccounts.Migrations.SchemaMigration, for: Any do
  def migrate(item, _, _), do: item
end
