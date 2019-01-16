defmodule ApiAccountsTest do
  use ApiAccounts.Test.DatabaseCase, async: false
  alias ApiAccounts.{Changeset, Key, NoResultsError, User}

  @valid_attrs %{
    active: true,
    blocked: true,
    join_date: DateTime.from_naive!(~N[2010-04-17 14:00:00], "Etc/UTC"),
    phone: "some phone",
    username: "some username",
    email: "test@test.com"
  }

  describe "users" do
    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> ApiAccounts.create_user()

      user
    end

    def setup_user(_) do
      {:ok, user: user_fixture()}
    end

    @update_attrs %{
      active: false,
      blocked: false,
      join_date: DateTime.from_naive!(~N[2011-05-18 15:01:01], "Etc/UTC"),
      phone: "some updated phone",
      email: "new_test@test.com"
    }
    @invalid_attrs %{
      active: nil,
      blocked: nil,
      join_date: nil,
      phone: nil
    }

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert ApiAccounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert ApiAccounts.get_user!(user.id) == user
    end

    test "get_user!/1 raises when no user is returned" do
      assert_raise NoResultsError, fn -> ApiAccounts.get_user!("bad_id") end
    end

    test "get_user/1" do
      user = user_fixture()
      assert ApiAccounts.get_user(user.id) == {:ok, user}
      assert ApiAccounts.get_user("bad_id") == {:error, :not_found}
    end

    test "get_user_by_email/1" do
      user = user_fixture()
      assert ApiAccounts.get_user_by_email(user.email) == {:ok, user}
      assert ApiAccounts.get_user_by_email("bad_id") == {:error, :not_found}

      assert ApiAccounts.get_user_by_email(%{email: user.email}) == {:ok, user}
      assert {:error, changeset} = ApiAccounts.get_user_by_email(%{email: "bad_format"})
      refute changeset.valid?
      assert Enum.at(changeset.errors.email, 0) =~ "format"
    end

    test "get_user_by_email!/1" do
      user = user_fixture()
      assert ApiAccounts.get_user_by_email!(user.email) == user

      assert_raise NoResultsError, fn ->
        ApiAccounts.get_user_by_email!("bad")
      end
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = ApiAccounts.create_user(@valid_attrs)
      assert user.active == @valid_attrs.active
      assert user.blocked == @valid_attrs.blocked
      assert user.join_date == @valid_attrs.join_date
      assert user.phone == @valid_attrs.phone
      assert user.username == @valid_attrs.username
      assert user.email == @valid_attrs.email
      assert user.id != nil
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Changeset{}} = ApiAccounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, user} = ApiAccounts.update_user(user, @update_attrs)
      assert %User{} = user
      assert user.active == @update_attrs.active
      assert user.blocked == @update_attrs.blocked
      assert user.join_date == @update_attrs.join_date
      assert user.phone == @update_attrs.phone
      assert user.email == @update_attrs.email
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Changeset{}} = ApiAccounts.update_user(user, @invalid_attrs)
      assert user == ApiAccounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user and their keys" do
      user = user_fixture()

      for _ <- 1..5 do
        {:ok, _} = ApiAccounts.create_key(user)
      end

      assert ApiAccounts.delete_user(user) == :ok
      assert_raise NoResultsError, fn -> ApiAccounts.get_user!(user.id) end
      assert ApiAccounts.list_keys_for_user(user) == []
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Changeset{} = ApiAccounts.change_user(user)
    end
  end

  describe "users register_user/1" do
    @register_attrs %{
      email: "test@test.com",
      password: "password",
      password_confirmation: "password"
    }

    test "creates a user" do
      assert {:ok, user} = ApiAccounts.register_user(@register_attrs)
      assert user.email == @register_attrs.email
    end

    test "enforces password length" do
      params = %{
        email: "test@test.com",
        password: "test",
        password_confirmation: "test"
      }

      assert {:error, result} = ApiAccounts.register_user(params)
      assert Enum.at(result.errors.password, 0) =~ "at least"
    end

    test "enforces password confirmation matches" do
      params = Map.put(@register_attrs, :password_confirmation, "passwordd")
      assert {:error, result} = ApiAccounts.register_user(params)
      assert Enum.at(result.errors.password_confirmation, 0) =~ "match"
    end

    test "doesn't allow duplicate email addresses" do
      assert {:ok, _} = ApiAccounts.register_user(@register_attrs)
      assert {:error, result} = ApiAccounts.register_user(@register_attrs)
      assert Enum.at(result.errors.email, 0) =~ "taken"
    end

    test "enforces an emails to be an email format" do
      params = Map.put(@register_attrs, :email, "test")
      assert {:error, result} = ApiAccounts.register_user(params)
      assert Enum.at(result.errors.email, 0) =~ "format"
    end
  end

  describe "create_key/2" do
    setup :setup_user

    test "can create a key (unapproved)", %{user: user} do
      assert {:ok, key} = ApiAccounts.create_key(user)
      assert key.user_id == user.id
      refute key.api_version == nil
      refute key.created == nil
      refute key.key == nil
      refute key.approved
    end

    test "can create a key (approved)", %{user: user} do
      assert {:ok, key} = ApiAccounts.create_key(user, %{approved: true})
      assert key.approved
      refute key.api_version == nil
    end
  end

  describe "keys" do
    setup :setup_user

    test "get_key/1", %{user: user} do
      {:ok, key} = ApiAccounts.create_key(user)
      assert ApiAccounts.get_key(key.key) == {:ok, key}
      assert ApiAccounts.get_key("bad_id") == {:error, :not_found}
      assert ApiAccounts.get_key(user.id, key.key) == {:ok, key}
      assert ApiAccounts.get_key(user.id, "bad_id") == {:error, :not_found}
      assert ApiAccounts.get_key("other_user", key.key) == {:error, :not_found}
    end

    test "get_key!/1", %{user: user} do
      {:ok, key} = ApiAccounts.create_key(user)
      assert ApiAccounts.get_key!(key.key) == key
      assert ApiAccounts.get_key!(user.id, key.key) == key

      assert_raise ApiAccounts.NoResultsError, fn ->
        ApiAccounts.get_key!("bad_id")
      end

      assert_raise ApiAccounts.NoResultsError, fn ->
        ApiAccounts.get_key!(user.id, "bad_id")
      end

      assert_raise ApiAccounts.NoResultsError, fn ->
        ApiAccounts.get_key!("other_user", key.key)
      end
    end

    test "list_keys_for_user/1", %{user: user} do
      {:ok, _} = ApiAccounts.create_key(user)
      {:ok, _} = ApiAccounts.create_key(user)

      results = ApiAccounts.list_keys_for_user(user)
      assert length(results) == 2
      [key1, key2] = results
      assert key1.key != key2.key

      for key <- results do
        assert key.user_id == user.id
      end

      assert ApiAccounts.list_keys_for_user(%ApiAccounts.User{id: "bad"}) == []
    end

    test "change_key/1 returns a user changeset", %{user: user} do
      {:ok, key} = ApiAccounts.create_key(user)
      assert %Changeset{} = ApiAccounts.change_key(key)
    end
  end

  describe "request_key/1" do
    setup do
      {:ok, user} = ApiAccounts.create_user(@valid_attrs)
      {:ok, user: user}
    end

    test "creates a key", %{user: user} do
      assert {:ok, %Key{} = key} = ApiAccounts.request_key(user)
      assert key.requested_date
    end

    test "automatically approves the first key", %{user: user} do
      {:ok, key} = ApiAccounts.request_key(user)
      assert key.approved
    end

    test "does not approve a second key", %{user: user} do
      {:ok, _} = ApiAccounts.request_key(user)
      {:ok, key} = ApiAccounts.request_key(user)
      refute key.approved
    end

    test "only allows 1 reqest at at time for a user", %{user: user} do
      {:ok, _} = ApiAccounts.request_key(user)
      {:ok, _} = ApiAccounts.request_key(user)
      assert :error == ApiAccounts.request_key(user)
    end
  end

  describe "update_key/2" do
    setup do
      {:ok, key} = ApiAccounts.request_key(%User{id: "test"})
      {:ok, key: key}
    end

    test "updates a key", %{key: key} do
      update_params = %{approved: true, locked: true, daily_limit: 10_000}
      assert {:ok, result} = ApiAccounts.update_key(key, update_params)
      assert result.approved == update_params.approved
      assert result.locked == update_params.locked
      assert result.daily_limit == update_params.daily_limit
    end
  end

  test "list_key_requests/0" do
    expected =
      for i <- 1..5 do
        {:ok, user} = ApiAccounts.create_user(%{email: "test#{i}@test.com"})
        {:ok, _approved_key} = ApiAccounts.request_key(user)
        {:ok, key} = ApiAccounts.request_key(user)
        {key, user}
      end

    for i <- 1..2 do
      {:ok, user} = ApiAccounts.create_user(%{email: "test#{i}-#{i}@test.com"})
      {:ok, key} = ApiAccounts.create_key(user)
      ApiAccounts.update_key(key, %{approved: true})
    end

    result = ApiAccounts.list_key_requests()
    assert Enum.sort(result) == Enum.sort(expected)
  end

  describe "can_request_key?/1" do
    test "checks by user" do
      {:ok, user} = ApiAccounts.create_user(%{email: "test@test.com"})
      assert ApiAccounts.can_request_key?(user)

      {:ok, key} = ApiAccounts.create_key(user)
      refute ApiAccounts.can_request_key?(user)

      {:ok, _key} = ApiAccounts.update_key(key, %{approved: true})
      assert ApiAccounts.can_request_key?(user)
    end

    test "checks by a user's keys" do
      {:ok, user} = ApiAccounts.create_user(%{email: "test@test.com"})
      keys = ApiAccounts.list_keys_for_user(user)
      assert ApiAccounts.can_request_key?(keys)

      {:ok, key} = ApiAccounts.create_key(user)
      keys = ApiAccounts.list_keys_for_user(user)
      refute ApiAccounts.can_request_key?(keys)

      {:ok, _key} = ApiAccounts.update_key(key, %{approved: true})
      keys = ApiAccounts.list_keys_for_user(user)
      assert ApiAccounts.can_request_key?(keys)
    end
  end

  describe "auto_approve_key?/1" do
    test "true if the user has no other keys" do
      {:ok, user} = ApiAccounts.create_user(%{email: "test@test.com"})
      assert ApiAccounts.auto_approve_key?(user)
    end

    test "false if the user has other keys" do
      {:ok, user} = ApiAccounts.create_user(%{email: "test@test.com"})
      {:ok, _} = ApiAccounts.create_key(user)
      refute ApiAccounts.auto_approve_key?(user)
    end
  end

  describe "authenticate/1" do
    @test_password "test_password"

    setup do
      attrs = Map.put(@valid_attrs, :password, @test_password)
      {:ok, user} = ApiAccounts.create_user(attrs)
      {:ok, user: user}
    end

    test "returns user when credentials are valid", %{user: user} do
      params = %{email: user.email, password: @test_password}
      assert {:ok, user} == ApiAccounts.authenticate(params)
    end

    test "returns error when password doesn't match", %{user: user} do
      params = %{email: user.email, password: "bad_password"}
      assert {:error, :invalid_credentials} == ApiAccounts.authenticate(params)
    end

    test "returns error when user isn't found" do
      params = %{email: "bad_id", password: "bad_password"}
      assert {:error, :invalid_credentials} == ApiAccounts.authenticate(params)
    end

    test "returns error when :password or :email not present" do
      assert {:error, %ApiAccounts.Changeset{valid?: false}} = ApiAccounts.authenticate(%{})

      assert {:error, %ApiAccounts.Changeset{valid?: false}} =
               ApiAccounts.authenticate(%{email: ""})

      assert {:error, %ApiAccounts.Changeset{valid?: false}} =
               ApiAccounts.authenticate(%{password: ""})

      assert {:error, %ApiAccounts.Changeset{valid?: false}} =
               ApiAccounts.authenticate(%{email: "", password: ""})
    end
  end

  describe "update_password/2" do
    setup do
      params = %{email: "test@test", password: "password"}
      {:ok, user} = ApiAccounts.create_user(params)
      {:ok, user: user}
    end

    test "updates user with new password", %{user: user} do
      params = %{
        password: "new_password",
        password_confirmation: "new_password"
      }

      assert {:ok, user} = ApiAccounts.update_password(user, params)
      refute user.password == params.password
      assert Comeonin.Bcrypt.checkpw(params.password, user.password)
    end

    test "enforces a minimum password length", %{user: user} do
      params = %{
        password: "short",
        password_confirmation: "short"
      }

      assert {:error, changeset} = ApiAccounts.update_password(user, params)
      refute changeset.valid?
      assert Enum.at(changeset.errors.password, 0) =~ "at least"
    end

    test "asserts passwords match", %{user: user} do
      params = %{
        password: "password",
        password_confirmation: "other_password"
      }

      assert {:error, changeset} = ApiAccounts.update_password(user, params)
      refute changeset.valid?
      assert Enum.at(changeset.errors.password_confirmation, 0) =~ "match"
    end
  end

  describe "update_information/2" do
    setup do
      {:ok, user} = ApiAccounts.create_user(@valid_attrs)
      {:ok, user: user}
    end

    test "updates account information", %{user: user} do
      params = %{
        email: user.email,
        phone: "1234567"
      }

      assert {:ok, user} = ApiAccounts.update_information(user, params)
      assert user.phone == params.phone
    end

    test "doesn't allow duplicate emails when changing email", %{user: user} do
      {:ok, _} = ApiAccounts.update_information(user, %{email: "existing@test"})
      assert {:error, changeset} = ApiAccounts.update_information(user, %{email: "existing@test"})
      refute changeset.valid?
      assert Enum.at(changeset.errors.email, 0) =~ "taken"
    end

    test "enforces an email format", %{user: user} do
      assert {:error, changeset} = ApiAccounts.update_information(user, %{email: "bad_format"})
      refute changeset.valid?
      assert Enum.at(changeset.errors.email, 0) =~ "format"
    end

    test "requires an email address in params", %{user: user} do
      assert {:error, changeset} = ApiAccounts.update_information(user, %{})
      refute changeset.valid?
      assert Enum.at(changeset.errors.email, 0) =~ "required"
    end
  end

  test "list_administators" do
    {:ok, admin} =
      ApiAccounts.create_user(%{id: "admin", email: "admin@test", role: "administrator"})

    ApiAccounts.create_user(%{id: "user", email: "user@test"})

    assert [admin] == ApiAccounts.list_administrators()
  end
end
