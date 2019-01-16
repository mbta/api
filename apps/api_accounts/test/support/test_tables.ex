defmodule ApiAccounts.Test.Model do
  @moduledoc false
  use ApiAccounts.Table

  table "model_table" do
    field(:email, :string, primary_key: true)
    field(:username, :string, secondary_index: true)
    field(:name, :string)
    field(:active, :boolean, default: true)
    field(:secret, :string, virtual: true)
    schema_version(1)
  end
end

defmodule ApiAccounts.Test.ModelWithoutSecondary do
  @moduledoc false
  use ApiAccounts.Table

  table "model_without_secondary_table" do
    field(:email, :string, primary_key: true)
    field(:name, :string)
    field(:secret, :string, virtual: true)
    schema_version(1)
  end
end

defmodule ApiAccounts.Test.MigrationModel do
  @moduledoc false
  use ApiAccounts.Table

  table "migration_test" do
    field(:id, :string, primary_key: true)
    field(:date, :datetime)
    field(:name, :string)
    schema_version(2)
  end
end
