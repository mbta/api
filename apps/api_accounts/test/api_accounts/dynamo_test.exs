defmodule ApiAccounts.DynamoTest do
  use ApiAccounts.Test.DatabaseCase, async: false
  alias ApiAccounts.{Dynamo, Key, User}

  def put_user(attrs) do
    {:ok, %User{} = user} = Dynamo.put_item(struct(User, attrs))
    user
  end

  test "create_table" do
    assert {:ok, _} = Dynamo.create_table(ApiAccounts.Test.Model)
    assert {:ok, _} = Dynamo.create_table(ApiAccounts.Test.ModelWithoutSecondary)
  end

  test "put_item and fetch_item" do
    assert {:error, :not_found} = Dynamo.fetch_item(User, %{id: "me@example"})
    user = put_user(id: "test", email: "me@example")
    assert user.email == "me@example"
    assert {:ok, ^user} = Dynamo.fetch_item(User, %{id: user.id})

    assert {:ok, item} = Dynamo.fetch_item(User.table_info().name, %{id: user.id})
    assert ^user = ExAws.Dynamo.decode_item(item, as: User)

    assert {:error, :not_found} = Dynamo.fetch_item(User, %{id: "not_found"})
  end

  test "put_item nil integer is returned" do
    assert {:ok, %Key{} = key} =
             Dynamo.put_item(%Key{key: "key", user_id: "user", daily_limit: nil})

    assert key.daily_limit == nil
    assert {:ok, ^key} = Dynamo.fetch_item(Key, %{key: "key"})
  end

  test "put_item doesn't persist virtual fields" do
    params = %User{
      id: "test",
      email: "me@example",
      password_confirmation: "test"
    }

    {:ok, user} = Dynamo.put_item(params)
    {:ok, user} = Dynamo.fetch_item(User, %{id: user.id})
    assert user.password_confirmation == nil
  end

  test "put_item checks for contraints" do
    changeset =
      %User{id: "test"}
      |> User.changeset(%{email: "me@example"})
      |> ApiAccounts.Changeset.unique_constraint(:email)

    assert {:ok, _} = Dynamo.put_item(changeset)

    assert {:error, result} = Dynamo.put_item(changeset)
    assert result.errors == %{email: ["has already been taken"]}
    assert result.valid? == false
    assert {:error, :not_found} = Dynamo.fetch_item(User, %{id: "test2"})
  end

  test "query and scan" do
    bob = put_user(id: "test1", email: "bob@example")
    tom = put_user(id: "test2", email: "tom@example")
    sue = put_user(id: "test3", email: "sue@example")
    assert Dynamo.query(User, "id = :id", %{id: bob.id}) == [bob]

    assert Dynamo.scan(User, "email = :tom OR email = :sue", %{tom: tom.email, sue: sue.email}) ==
             [sue, tom]
  end

  test "query on secondary index" do
    bob = put_user(id: "test", email: "bob@example")

    assert Dynamo.query(
             User,
             "email = :email",
             %{email: bob.email},
             index_name: "email_secondary_index"
           ) == [bob]
  end

  test "update_item" do
    user = put_user(id: "test", email: "test@example.com", phone: "1234567")

    expected_user =
      user
      |> Map.put(:active, false)
      |> Map.put(:phone, nil)

    assert {:ok, ^expected_user} = Dynamo.update_item(user, %{active: false, phone: ""})
    assert {:ok, ^expected_user} = Dynamo.fetch_item(User, %{id: "test"})
  end

  test "update_item doesn't persist virtual fields" do
    user = put_user(id: "test", email: "test@example.com", phone: "1234567")
    expected_user = Map.put(user, :phone, nil)

    assert {:ok, expected_user} ==
             Dynamo.update_item(user, %{phone: "", password_confirmation: "test"})

    assert {:ok, expected_user} == Dynamo.fetch_item(User, %{id: user.id})
  end

  test "update_item nil integer is returned" do
    assert {:ok, %Key{} = key} =
             Dynamo.put_item(%Key{key: "key", user_id: "user", daily_limit: 5})

    assert {:ok, new_key} = Dynamo.update_item(key, %{daily_limit: nil})
    assert new_key.daily_limit == nil
  end

  test "delete_item" do
    user = put_user(id: "test", email: "test@example.com")
    {:ok, ^user} = Dynamo.fetch_item(User, %{id: "test"})
    assert Dynamo.delete_item(user) == :ok
    assert {:error, :not_found} == Dynamo.fetch_item(User, %{id: "test"})
  end

  describe "migrate_table/1" do
    alias ApiAccounts.Test.MigrationModel

    setup do
      {:ok, _} = Dynamo.create_table(MigrationModel)

      for i <- 1..5 do
        item = %MigrationModel{
          id: "#{i}",
          date: NaiveDateTime.utc_now(),
          name: "test",
          schema_version: 0
        }

        {:ok, _} = Dynamo.put_item(item)
      end
    end

    test "migrates a table" do
      Dynamo.migrate_table(MigrationModel)

      for item <- Dynamo.scan(MigrationModel) do
        assert item.schema_version == 2
        assert item.name == "TEST"
        assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(item.date)
      end
    end
  end

  describe "migrate/0" do
    test "migrates users" do
      for i <- 1..5 do
        user = %User{
          id: "#{i}",
          email: "#{i}@example.com",
          join_date: NaiveDateTime.utc_now(),
          schema_version: 0
        }

        {:ok, _} = Dynamo.put_item(user)
      end

      Dynamo.migrate()

      for user <- Dynamo.scan(User) do
        assert %DateTime{} = user.join_date
        assert user.schema_version == 1
      end
    end

    test "migrates keys" do
      for i <- 1..5 do
        key = %Key{
          key: "#{i}",
          user_id: "#{i}",
          requested_date: NaiveDateTime.utc_now(),
          created: NaiveDateTime.utc_now(),
          schema_version: 0
        }

        {:ok, _} = Dynamo.put_item(key)
      end

      Dynamo.migrate()

      for key <- Dynamo.scan(Key) do
        assert %DateTime{} = key.requested_date
        assert %DateTime{} = key.created
        assert is_boolean(key.rate_request_pending)
        assert key.api_version == "2017-11-28"
        assert key.schema_version == 3
      end
    end
  end

  describe "decode/2" do
    test "decodes items" do
      expected_user = %User{email: "test@example.com"}

      attrs = %{
        "email" => %{"S" => expected_user.email},
        "schema_version" => %{"N" => "#{User.table_info().schema_version}"}
      }

      assert Dynamo.decode(attrs, User) == expected_user
      assert Dynamo.decode(%{"Item" => attrs}, User) == expected_user
    end

    test "assigns a default schema version of 0 when none present" do
      expected_user = %User{email: "test@example.com", schema_version: 0}
      attrs = %{"email" => %{"S" => expected_user.email}}
      assert Dynamo.decode(attrs, User) == expected_user
    end
  end
end
