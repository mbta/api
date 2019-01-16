defmodule ApiAccounts.UserTest do
  use ExUnit.Case, async: true
  alias ApiAccounts.User

  test "changeset/2" do
    changes = %{
      email: "test@test.com",
      role: "test",
      username: "test",
      phone: "test",
      join_date: DateTime.from_naive!(~N[2017-01-01T00:00:00], "Etc/UTC"),
      active: false,
      blocked: true
    }

    assert %ApiAccounts.Changeset{data: %User{}, changes: ^changes} =
             User.changeset(%User{}, changes)
  end

  test "new/3 generates a unique ID for a user" do
    changes = %{email: "test@test.com", password: "password"}
    changeset = User.new(%User{}, changes)
    assert changeset.changes[:id] != nil
  end

  test "new/3 hashes an applied password" do
    changes = %{email: "test@test.com", password: "password"}

    changeset = User.new(%User{}, changes)
    refute changeset.changes.password == changes.password
    assert Comeonin.Bcrypt.checkpw(changes.password, changeset.changes.password)
  end

  test "update/3 shouldn't include password" do
    changes = %{password: "password"}

    changeset = User.update(%User{}, changes)
    refute changeset.changes[:password]
  end

  test "authenticate/2" do
    params = %{}
    result = User.authenticate(%User{}, params)
    assert Enum.at(result.errors.email, 0) =~ "required"
    assert Enum.at(result.errors.password, 0) =~ "required"
    refute result.valid?

    params = %{email: "test@test", password: "password"}
    result = User.authenticate(%User{}, params)
    assert result.errors == %{}
    assert result.valid?
  end

  describe "register/2" do
    @register_params %{
      email: "test@test",
      password: "password",
      password_confirmation: "password"
    }

    test "requires fields" do
      result = User.register(%User{}, %{})
      assert Enum.at(result.errors.email, 0) =~ "required"
      assert Enum.at(result.errors.password, 0) =~ "required"
      assert Enum.at(result.errors.password_confirmation, 0) =~ "required"
      refute result.valid?
    end

    test "enforces minimum password length" do
      params = %{
        email: "test@test",
        password: "short",
        password_confirmation: "short"
      }

      result = User.register(%User{}, params)
      assert Enum.at(result.errors.password, 0) =~ "at least"
      refute result.valid?
    end

    test "enforces matching passwords" do
      params = Map.put(@register_params, :password_confirmation, "notthesame")
      result = User.register(%User{}, params)
      assert Enum.at(result.errors.password_confirmation, 0) =~ "match"
      refute result.valid?
    end

    test "enforces email is in an email format" do
      params = Map.put(@register_params, :email, "test")
      result = User.register(%User{}, params)
      assert Enum.at(result.errors.email, 0) =~ "format"
      refute result.valid?
    end

    test "trims and downcases email addresses" do
      params = Map.put(@register_params, :email, " TEST@TeSt.CoM    ")
      result = User.register(%User{}, params)
      assert result.changes.email == "test@test.com"
      assert result.valid?
    end

    test "sets unique id when valid" do
      result = User.register(%User{}, @register_params)
      assert result.changes.id
      assert result.valid?
    end

    test "hashes password when valid" do
      result = User.register(%User{}, @register_params)
      assert result.changes.password != @register_params.password
      assert result.valid?
      assert Comeonin.Bcrypt.checkpw(@register_params.password, result.changes.password)
    end
  end

  describe "update_password/2" do
    test "requires fields" do
      result = User.update_password(%User{}, %{})
      assert Enum.at(result.errors.password, 0) =~ "required"
      assert Enum.at(result.errors.password_confirmation, 0) =~ "required"
      refute result.valid?
    end

    test "enforces minimum password length" do
      params = %{
        password: "short",
        password_confirmation: "short"
      }

      result = User.update_password(%User{}, params)
      assert Enum.at(result.errors.password, 0) =~ "at least"
      refute result.valid?
    end

    test "enforces matching passwords" do
      params = %{
        password: "password",
        password_confirmation: "other_password"
      }

      result = User.update_password(%User{}, params)
      assert Enum.at(result.errors.password_confirmation, 0) =~ "match"
      refute result.valid?
    end

    test "hashes password when valid" do
      params = %{
        password: "password",
        password_confirmation: "password"
      }

      result = User.update_password(%User{}, params)
      assert result.changes.password != params.password
      assert result.valid?
      assert Comeonin.Bcrypt.checkpw(params.password, result.changes.password)
    end
  end

  describe "account_recovery/1" do
    test "requires email" do
      result = User.account_recovery(%{})
      assert Enum.at(result.errors.email, 0) =~ "required"
      refute result.valid?
    end

    test "enforces email is in an email format" do
      result = User.account_recovery(%{email: "test"})
      assert Enum.at(result.errors.email, 0) =~ "format"
      refute result.valid?
    end

    test "trims and downcases email addresses" do
      result = User.account_recovery(%{email: " TEST@TeSt.CoM    "})
      assert result.changes.email == "test@test.com"
      assert result.valid?
    end
  end
end
