defimpl ApiAccounts.Migrations.SchemaMigration, for: ApiAccounts.User do
  alias ApiAccounts.User

  def migrate(%User{join_date: nil} = user, 0, 1), do: user

  def migrate(%User{join_date: join_date} = user, 0, 1) do
    join_date = DateTime.from_naive!(join_date, "Etc/UTC")
    %User{user | join_date: join_date, schema_version: 1}
  end
end

defimpl ApiAccounts.Migrations.SchemaMigration, for: ApiAccounts.Key do
  alias ApiAccounts.Key

  def migrate(%Key{} = key, 0, 1) do
    created =
      if key.created do
        DateTime.from_naive!(key.created, "Etc/UTC")
      end

    requested_date =
      if key.requested_date do
        DateTime.from_naive!(key.requested_date, "Etc/UTC")
      end

    %Key{key | created: created, requested_date: requested_date, schema_version: 1}
  end

  def migrate(%Key{} = key, 1, 2) do
    %Key{key | rate_request_pending: false, schema_version: 2}
  end

  def migrate(%Key{} = key, 2, 3) do
    %Key{key | api_version: "2017-11-28", schema_version: 3}
  end
end
