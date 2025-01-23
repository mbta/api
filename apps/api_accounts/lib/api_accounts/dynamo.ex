defmodule ApiAccounts.Dynamo do
  @moduledoc """
  Interface for operations with DynamoDB.
  """

  alias ApiAccounts.{Changeset, Migrations.SchemaMigration}

  @read_capacity 1
  @write_capacity 1

  @doc """
  Deletes all tables with the configured prefix from DynamoDB.
  """
  def delete_all_tables do
    table_prefix = Application.get_env(:api_accounts, :table_prefix)
    {:ok, %{"TableNames" => tables}} = request(ExAws.Dynamo.list_tables())

    for table <- tables, String.starts_with?(table, table_prefix) do
      {:ok, _} = request(ExAws.Dynamo.delete_table(table))
    end
  end

  @doc """
  Creates a table in DynamoDB.

  You create a table from a module that uses `ApiAccounts.Table`. You can also
  supply table information directly.
  See [ExAws docs](https://hexdocs.pm/ex_aws/ExAws.Dynamo.html#create_table/7)
  for full type information.

  ## Examples

      create_table(User)
      create_table("users", %{email: :hash} , %{email: :string})
      create_table("users", %{email: :hash} , %{email: :string},
                   [secondary_indexes])

  """
  def create_table(module) when is_atom(module) do
    info = module.table_info()

    create_table(
      info.name,
      info.key_schema,
      info.key_definitions,
      info.secondary_index_definitions
    )
  end

  def create_table(table, key_schema, key_definitions, secondary_indexes \\ [])
      when is_binary(table) do
    table
    |> ExAws.Dynamo.create_table(
      key_schema,
      key_definitions,
      @read_capacity,
      @write_capacity,
      secondary_indexes,
      []
    )
    |> request()
  end

  @doc """
  Fetches an item based on the matcher.

  Matcher is expected to be a map of index => value.

  Whenever a module is provided, the fetched item is returned in a struct.

  ## Examples

      iex> fetch_item(User, %{id: "test"})
      {:ok, ...}

      iex> fetch_item("api_accounts_users", %{id: "test"})
      {:ok, ...}

      iex> fetch_item(User, %{id: "bad_id"})
      {:error, ...}

  """
  @spec fetch_item(atom, %{optional(atom) => any}) ::
          {:ok, map} | {:error, :not_found} | {:error, any}
  def fetch_item(module, %{} = matching) when is_atom(module) do
    module.table_info().name
    |> ExAws.Dynamo.get_item(matching)
    |> request()
    |> case do
      {:ok, empty} when empty == %{} -> {:error, :not_found}
      {:ok, %{} = item} -> {:ok, decode(item, module)}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec fetch_item(String.t(), %{optional(atom) => any}) ::
          {:ok, map} | {:error, :not_found} | {:error, any}
  def fetch_item(table, %{} = matching) when is_binary(table) do
    case request(ExAws.Dynamo.get_item(table, matching)) do
      {:ok, empty} when empty == %{} -> {:error, :not_found}
      {:ok, %{} = item} -> {:ok, item}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a new record or completely replaces an existing record based on
  primary key index.

  ## Examples

      iex> put_item(changeset)
      {:ok, ...}

      iex> put_item(user)
      {:ok, ...)

      iex> put_item(user)
      {:error, ...}

  """
  @spec put_item(Changeset.t() | struct) :: {:ok, map} | {:error, any}
  def put_item(%Changeset{data: item, changes: changes, valid?: true, constraints: []}) do
    item = Map.merge(item, changes)
    put_item(item)
  end

  def put_item(%Changeset{valid?: true} = changeset) do
    case check_constraints(changeset) do
      %{valid?: true, data: item, changes: changes} ->
        item = Map.merge(item, changes)
        put_item(item)

      changeset ->
        {:error, changeset}
    end
  end

  def put_item(%mod{} = item) do
    %{name: table_name, virtual_fields: virtual_fields} = mod.table_info()
    serialized_item = Map.drop(item, virtual_fields)

    table_name
    |> ExAws.Dynamo.put_item(serialized_item)
    |> request()
    |> case do
      {:ok, _} -> {:ok, item}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_constraints(%Changeset{} = changeset) do
    Enum.reduce(changeset.constraints, changeset, &do_check_constraint/2)
  end

  defp do_check_constraint(%{type: :unique} = constraint, changeset) do
    field = constraint.field
    field_value = Map.get(changeset.changes, field)
    item_value = Map.get(changeset.data, field)

    # Only check the constraint when the values do not match
    if item_value != field_value do
      records =
        query(
          changeset.source,
          "#{field} = :#{field}",
          %{field => field_value},
          index_name: "#{field}_secondary_index"
        )

      if records == [] do
        changeset
      else
        {field, [constraint.message]}
        |> Changeset.append_error(changeset)
        |> Map.put(:valid?, false)
      end
    else
      changeset
    end
  end

  @doc """
  Updates an item with the specified new values.

  When an item is successfully updated, a struct with all the lastest values is
  returned.

  ## Examples

      iex> update_item(changeset)
      {:ok, ...}

      iex> update_item(user, %{role: "role")
      {:ok, ...}

      iex> update(item, user, %{role: nil})
      {:error, ...}

  """
  @spec update_item(Changeset.t()) :: {:ok, map} | {:error, any}
  def update_item(%Changeset{data: data, changes: changes, valid?: true, constraints: []}) do
    update_item(data, changes)
  end

  def update_item(%Changeset{valid?: true} = changeset) do
    case check_constraints(changeset) do
      %{valid?: true, data: item, changes: changes} ->
        item = Map.merge(item, changes)
        put_item(item)

      changeset ->
        {:error, changeset}
    end
  end

  @spec update_item(map, map) :: {:ok, map} | {:error, any}
  def update_item(%mod{} = item, changes) do
    virtual_fields = mod.table_info().virtual_fields
    changes = Map.drop(changes, virtual_fields)

    update_expression = update_expression(changes)
    update_names = update_expression_names(changes)
    update_values = for {k, v} <- changes, v != "", into: %{}, do: {k, v}

    default_opts = [
      update_expression: update_expression,
      expression_attribute_names: update_names,
      return_values: :all_new
    ]

    # Remove empty :expression_attribute_value from keyword list if no values
    update_opts =
      if update_values == %{} do
        default_opts
      else
        Keyword.put(default_opts, :expression_attribute_values, update_values)
      end

    mod.table_info().name
    |> ExAws.Dynamo.update_item(mod.pkey_matcher(item), update_opts)
    |> request()
    |> case do
      {:ok, %{"Attributes" => attrs}} -> {:ok, decode(%{"Item" => attrs}, mod)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Create update expression like "SET #field1 = :field1, #field2 = :field2"
  defp update_expression(changes) when is_map(changes) do
    set_expression_fields =
      for {field, value} <- changes, value != "" do
        "##{field} = :#{field}"
      end

    remove_expression_fields =
      for {field, value} <- changes, value == "" do
        "##{field}"
      end

    set_expression =
      if set_expression_fields == [] do
        ""
      else
        "SET " <> Enum.join(set_expression_fields, ", ")
      end

    remove_expression =
      if remove_expression_fields == [] do
        ""
      else
        "REMOVE " <> Enum.join(remove_expression_fields, ", ")
      end

    set_expression <> " " <> remove_expression
  end

  # Convert attribute names to %{"#attr" => "attr"} to ensure no
  # reserved names aren't used
  defp update_expression_names(changes) when is_map(changes) do
    for {field, _value} <- changes do
      field_string = Atom.to_string(field)
      {"##{field_string}", field_string}
    end
  end

  @doc """
  Deletes an item.

  Item should be a struct that was defined using `ApiAccounts.Table.table/2`.

  ## Examples

      iex> delete_item(item)
      :ok

      iex> delete_item(item)
      {:error, ...}

  """
  @spec delete_item(map) :: :ok | {:error, any}
  def delete_item(%mod{} = item) do
    mod.table_info().name
    |> ExAws.Dynamo.delete_item(mod.pkey_matcher(item))
    |> request()
    |> case do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Queries a table defined in a module on an index or partition key with matching
  values.

  ## Examples

      iex> query(User, "email = :email", %{email: "test@example.com"})
      [...]

  """
  @spec query(atom, String.t(), %{optional(atom) => any}, Keyword.t()) :: [map]
  def query(mod, key_conds, expression_attrs, opts \\ []) when is_atom(mod) do
    base_opts = [
      expression_attribute_values: expression_attrs,
      key_condition_expression: key_conds
    ]

    base_opts
    |> Keyword.merge(opts)
    |> do_paginated_query(:query, mod, [])
    |> Enum.flat_map(fn
      %Task{} = task -> Task.await(task)
      results when is_list(results) -> results
    end)
  end

  @doc """
  Lists all items from a table.

  Items can additionally be filtered from the DynamoDB side prior to receiving
  any results by providing a filter expression and values.

  ## Examples

      iex> scan(User)
      [...]

      iex> scan(User, "active = :active", %{active: true})
      [...]

  """
  @spec scan(atom) :: [map]
  def scan(mod) when is_atom(mod) do
    []
    |> do_paginated_query(:scan, mod, [])
    |> Enum.flat_map(fn
      %Task{} = task -> Task.await(task)
      results when is_list(results) -> results
    end)
  end

  @spec scan(atom, String.t(), %{optional(atom) => any}) :: [map]
  def scan(mod, filter_expression, expression_attrs) when is_atom(mod) do
    opts = [
      expression_attribute_values: expression_attrs,
      filter_expression: filter_expression
    ]

    opts
    |> do_paginated_query(:scan, mod, [])
    |> Enum.flat_map(fn
      %Task{} = task -> Task.await(task)
      results when is_list(results) -> results
      _ -> []
    end)
  end

  defp do_paginated_query(opts, type, mod, acc) when type in [:query, :scan] do
    case request(apply(ExAws.Dynamo, type, [mod.table_info().name, opts])) do
      {:ok, %{"Items" => []}} ->
        acc

      {:ok, %{"Items" => [_ | _] = items, "LastEvaluatedKey" => start_key}} ->
        decode_task = Task.async(fn -> Enum.map(items, &decode(&1, mod)) end)

        opts
        |> Keyword.put(:exclusive_start_key, start_key)
        |> do_paginated_query(type, mod, [decode_task | acc])

      {:ok, %{"Items" => [_ | _] = items}} ->
        [Enum.map(items, &decode(&1, mod)) | acc]

      {:error, reason} ->
        {:error, reason}

      _  ->
        {:error, "unknown response"}
    end
  end

  @doc """
  Updates every item in the database to the latest schema versions.
  """
  def migrate do
    _ = create_table(ApiAccounts.User)
    _ = create_table(ApiAccounts.Key)
    _ = migrate_table(ApiAccounts.User)
    _ = migrate_table(ApiAccounts.Key)
  end

  @doc false
  def migrate_table(mod) do
    latest_version = mod.table_info().schema_version
    items = scan(mod)

    for item <- items, item.schema_version < latest_version do
      updated_item =
        item.schema_version
        |> Range.new(latest_version - 1)
        |> Enum.reduce(item, &SchemaMigration.migrate(&2, &1, &1 + 1))

      put_item(updated_item)
    end
  end

  @doc false
  def decode(%{"Item" => item}, mod), do: decode(item, mod)

  def decode(item, mod) do
    item = Map.put_new(item, "schema_version", %{"N" => "0"})
    ExAws.Dynamo.decode_item(item, as: mod)
  end

  defp request(req), do: ex_aws_client().request(req, config())
  defp ex_aws_client, do: ExAws

  def config do
    Application.get_env(:ex_aws, :dynamodb)
  end
end
