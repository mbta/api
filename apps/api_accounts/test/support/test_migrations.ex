defimpl ApiAccounts.Migrations.SchemaMigration, for: ApiAccounts.Test.MigrationModel do
  alias ApiAccounts.Test.MigrationModel

  def migrate(item, 0, 1) do
    date = NaiveDateTime.from_iso8601!(item.date)
    %MigrationModel{item | date: date, schema_version: 1}
  end

  def migrate(item, 1, 2) do
    name = String.upcase(item.name)
    date = DateTime.from_naive!(item.date, "Etc/UTC")
    %MigrationModel{item | name: name, date: date, schema_version: 2}
  end
end
