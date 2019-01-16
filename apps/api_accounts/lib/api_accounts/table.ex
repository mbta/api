defmodule ApiAccounts.Table do
  @moduledoc """
  Describes a DynamoDB table.

  You can define a table schema in use with DynamoDB. Each defined table
  will also have a struct and helper functions defined for the module.
  Additionally, each struct will be able to be encodable and decodable
  with DynamoDB.

  ## Example

      defmodule User do
        use ApiAccounts.Table

        table "users" do
          field :email, :string, primary_key: true
          field :uid, :string, secondary_index: true
          field :name, :string
          field :active, :boolean, default: true
          schema_version 1
        end
      end

  """
  @doc false
  defmacro __using__(_) do
    quote do
      import ApiAccounts.Table, only: [table: 2]

      @derive [ExAws.Dynamo.Encodable]
      @before_compile ApiAccounts.Table
    end
  end

  @doc """
  Defines a table with a table name and field definitions.
  """
  defmacro table(table_name, do: block) do
    quote do
      Module.register_attribute(__MODULE__, :struct_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :field_types, accumulate: true)
      Module.register_attribute(__MODULE__, :secondary_indexes, accumulate: true)
      Module.register_attribute(__MODULE__, :virtual_fields, accumulate: true)
      Module.put_attribute(__MODULE__, :primary_key, nil)
      Module.put_attribute(__MODULE__, :schema_version, nil)
      import ApiAccounts.Table
      unquote(block)

      # Create the struct
      defstruct Macro.escape(@struct_fields)
      @type t :: %__MODULE__{}

      @table_name unquote(table_name)

      # Convert field types to a map
      @fields_map Map.new(@field_types)

      # Generate any global secondary indexes
      @secondary_index_definitions Enum.map(@secondary_indexes, fn field ->
                                     %{
                                       index_name: "#{field}_secondary_index",
                                       key_schema: [
                                         %{
                                           attribute_name: "#{field}",
                                           key_type: "HASH"
                                         }
                                       ],
                                       provisioned_throughput: %{
                                         read_capacity_units: 1,
                                         write_capacity_units: 1
                                       },
                                       projection: %{
                                         projection_type: "ALL"
                                       }
                                     }
                                   end)

      # Get the types for any secondary indexes
      @secondary_index_types Enum.reduce(@secondary_indexes, %{}, fn f, acc ->
                               Map.put(acc, f, @fields_map[f])
                             end)

      # Map any keys to a type in a map
      @primary_key_definition %{@primary_key => @fields_map[@primary_key]}
      @key_definitions Map.merge(@primary_key_definition, @secondary_index_types)

      # Add functions to make table helper functions

      @doc """
      Information about table.
      """
      def table_info do
        %{
          name: table_name(),
          key_schema: %{
            @primary_key => :hash
          },
          key_definitions: @key_definitions,
          secondary_index_definitions: @secondary_index_definitions,
          field_types: @fields_map,
          virtual_fields: @virtual_fields,
          schema_version: @schema_version
        }
      end

      @doc """
      Generates a searchable term for the struct and its primary key.
      """
      def pkey_matcher(%__MODULE__{} = item) do
        %{@primary_key => Map.get(item, @primary_key)}
      end

      @doc """
      Retrieves the value of the primary key.
      """
      def pkey(%__MODULE__{} = item) do
        Map.get(item, @primary_key)
      end

      defp table_name do
        ApiAccounts.Table.__table_name__(@table_name)
      end
    end
  end

  @doc """
  Defines a field on the table with the given name.

  ## Options

    * `:default` - Sets the default value for the field and struct.
       The value is calculated at compile time.

    * `:primary_key` - Expects a boolean. If true, sets the field as the
      primary key for the table.

    * `:virtual` - Expects a boolean. When true, field is not persisted.

  """
  defmacro field(name, type, opts \\ []) do
    quote do
      ApiAccounts.Table.__field__(__MODULE__, unquote(name), unquote(type), unquote(opts))
    end
  end

  @doc false
  def __field__(mod, name, type, opts) do
    default = Keyword.get(opts, :default, nil)
    Module.put_attribute(mod, :struct_fields, {name, default})
    Module.put_attribute(mod, :field_types, {name, type})

    if opts[:primary_key] == true do
      if Module.get_attribute(mod, :primary_key) != nil do
        raise ArgumentError, "primary key already defined"
      end

      Module.put_attribute(mod, :primary_key, name)
    end

    if opts[:secondary_index] == true do
      Module.put_attribute(mod, :secondary_indexes, name)
    end

    if opts[:virtual] == true do
      Module.put_attribute(mod, :virtual_fields, name)
    end
  end

  @doc """
  Defines a schema version to associated to an individual item by default.
  """
  defmacro schema_version(version) when is_integer(version) do
    quote do
      ApiAccounts.Table.__field__(
        __MODULE__,
        :schema_version,
        :integer,
        default: unquote(version)
      )

      Module.put_attribute(__MODULE__, :schema_version, unquote(version))
    end
  end

  @doc false
  def __before_compile__(env) do
    unless Module.get_attribute(env.module, :struct_fields) do
      raise ArgumentError,
            "module #{inspect(env.module)} uses ApiAccounts.Table but it " <>
              "does not define a table."
    end

    unless Module.get_attribute(env.module, :primary_key) do
      raise ArgumentError,
            "module #{inspect(env.module)} uses ApiAccounts.Table but it " <>
              "does not define a primary key. Refer to ApiAccounts.Table.field/3."
    end

    unless Module.get_attribute(env.module, :schema_version) do
      raise ArgumentError,
            "module #{inspect(env.module)} uses ApiAccounts.Table but it " <>
              "does not define a schema version. Refer to " <>
              "ApiAccounts.Table.schema_version/1."
    end
  end

  @doc false
  def __table_name__(table_name) do
    Application.get_env(:api_accounts, :table_prefix) <> "_" <> table_name
  end
end
