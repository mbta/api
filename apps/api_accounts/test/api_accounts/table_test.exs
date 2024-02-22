defmodule ApiAccounts.TableTest do
  use ExUnit.Case, async: true

  alias ApiAccounts.Test.{Model, ModelWithoutSecondary}

  test "uses table attributes and default values to generate a struct" do
    assert %Model{name: "John Doe"}.name === "John Doe"
    assert %Model{}.active == true
  end

  test "generates function on module to retrieve pkey for module structs" do
    model = %Model{email: "test@example.com"}
    assert Model.pkey(model) == "test@example.com"
  end

  test "generates function on module to create matcher for module structs" do
    model = %Model{email: "test@example.com"}
    assert Model.pkey_matcher(model) == %{email: "test@example.com"}
  end

  test "generates function on module to get table information" do
    expected = %{
      name: "TEST_model_table",
      key_schema: %{email: :hash},
      key_definitions: %{email: :string, username: :string},
      field_types: %{
        email: :string,
        username: :string,
        name: :string,
        active: :boolean,
        secret: :string,
        schema_version: :integer
      },
      virtual_fields: [:secret],
      schema_version: 1,
      secondary_index_definitions: [
        %{
          index_name: "username_secondary_index",
          key_schema: [%{attribute_name: "username", key_type: "HASH"}],
          provisioned_throughput: %{
            read_capacity_units: 1,
            write_capacity_units: 1
          },
          projection: %{projection_type: "ALL"}
        }
      ]
    }

    assert Model.table_info() == expected

    expected = %{
      name: "TEST_model_without_secondary_table",
      key_schema: %{email: :hash},
      key_definitions: %{email: :string},
      field_types: %{email: :string, name: :string, secret: :string, schema_version: :integer},
      virtual_fields: [:secret],
      schema_version: 1,
      secondary_index_definitions: []
    }

    assert ModelWithoutSecondary.table_info() == expected
  end

  test "raises when no table is defined" do
    assert_raise ArgumentError, ~r"does not define a table", fn ->
      suppess_warnings(fn ->
        defmodule NoTable do
          use ApiAccounts.{Table}
        end
      end)
    end
  end

  test "raises when no primary key is defined" do
    assert_raise ArgumentError, ~r"does not define a primary key", fn ->
      suppess_warnings(fn ->
        defmodule NoPrimaryKey do
          use ApiAccounts.{Table}

          table "no_primary" do
            field(:name, :string)
            schema_version(1)
          end
        end
      end)
    end
  end

  test "raises when primary key is defined more than once" do
    assert_raise ArgumentError, ~r"primary key already defined", fn ->
      suppess_warnings(fn ->
        defmodule MultiPrimaryKey do
          use ApiAccounts.{Table}

          table "multi_primary" do
            field(:first_name, :string, primary_key: true)
            field(:last_name, :string, primary_key: true)
            schema_version(1)
          end
        end
      end)
    end
  end

  test "raises when no schema version is defined" do
    assert_raise ArgumentError, ~r"does not define a schema version", fn ->
      suppess_warnings(fn ->
        defmodule NoSchemaVersion do
          use ApiAccounts.{Table}

          table "no_schema_version" do
            field(:id, :string, primary_key: true)
          end
        end
      end)
    end
  end

  defp suppess_warnings(fun) do
    ExUnit.CaptureIO.capture_io(:stderr, fun)
  end
end
