defmodule ApiAccounts.ChangesetTest do
  use ExUnit.Case
  alias ApiAccounts.{Changeset, User}

  @data %ApiAccounts.User{
    username: "test",
    email: "test@test.com"
  }

  test "change/1" do
    assert Changeset.change(@data) == %Changeset{data: @data, source: User}
  end

  test "cast/1" do
    date = %{
      "year" => "2017",
      "month" => "1",
      "day" => "1",
      "hour" => "0",
      "minute" => "0"
    }

    params = %{
      email: "test2@test.com",
      role: "test",
      join_date: DateTime.from_naive!(~N[2017-01-01T00:00:00], "Etc/UTC")
    }

    string_params = %{
      "email" => "test2@test.com",
      "role" => "test",
      "join_date" => date
    }

    expected = %Changeset{
      data: @data,
      source: User,
      changes: %{
        role: "test",
        join_date: DateTime.from_naive!(~N[2017-01-01T00:00:00], "Etc/UTC")
      }
    }

    assert Changeset.cast(@data, params, [:role, :join_date]) == expected
    assert Changeset.cast(@data, string_params, [:role, :join_date]) == expected

    error_changeset = Changeset.cast(@data, %{"join_date" => %{}}, :join_date)
    refute error_changeset.valid?
    assert %{join_date: [_]} = error_changeset.errors
  end

  test "appends errors when more than one on a field" do
    changeset = %Changeset{
      changes: %{role: nil},
      errors: %{role: ["some_error"]}
    }

    assert %{errors: %{role: [_, _]}} = Changeset.validate_not_nil(changeset, [:role])
  end

  describe "validate_required/2" do
    setup do
      changeset = Changeset.cast(@data, %{role: "test"}, [:role])
      {:ok, %{changeset: changeset}}
    end

    test "marks as valid with req fields present", %{changeset: changeset} do
      result = Changeset.validate_required(changeset, [:role])
      assert result.errors == %{}
      assert result.valid? == true
    end

    test "marks as invalid with missing req field", %{changeset: changeset} do
      result = Changeset.validate_required(changeset, [:email])
      assert result.errors == %{email: ["is required"]}
      assert result.valid? == false
    end
  end

  describe "validate_not_nil/2" do
    setup do
      params = %{role: "test", phone: nil}
      changeset = Changeset.cast(@data, params, [:role, :phone])
      {:ok, %{changeset: changeset}}
    end

    test "marks as valid when not nil", %{changeset: changeset} do
      result = Changeset.validate_not_nil(changeset, [:role])
      assert result.errors == %{}
      assert result.valid? == true
    end

    test "marks as invalid when field is nil", %{changeset: changeset} do
      result = Changeset.validate_not_nil(changeset, :phone)
      assert result.errors == %{phone: ["cannot be nil"]}
      assert result.valid? == false
    end
  end

  describe "validate_confirmation/2" do
    test "marks as valid when confirmation field matches" do
      params = %{password: "password", password_confirmation: "password"}
      changeset = Changeset.cast(@data, params, [:password, :password_confirmation])
      result = Changeset.validate_confirmation(changeset, :password)
      assert result.errors == %{}
      assert result.valid? == true
    end

    test "marks as invalid when confirmation field doesn't match" do
      params = %{password: "password", password_confirmation: "password2"}
      changeset = Changeset.cast(@data, params, [:password, :password_confirmation])
      result = Changeset.validate_confirmation(changeset, :password)
      assert result.errors == %{password_confirmation: ["does not match password"]}
      assert result.valid? == false
    end
  end

  test "unique_contraint/2" do
    params = %{email: "test@test"}
    changeset = Changeset.cast(@data, params, :email)
    result = Changeset.unique_constraint(changeset, :email)

    expected = %{
      field: :email,
      message: "has already been taken",
      type: :unique
    }

    assert result.constraints == [expected]
  end

  describe "validate_email/2" do
    test "marks as invalid when supplying an invalid format email address" do
      params = %{email: "test"}
      changeset = Changeset.cast(@data, params, :email)
      result = Changeset.validate_email(changeset, :email)
      assert result.errors == %{email: ["has invalid format"]}
      assert result.valid? == false
    end

    test "marks as invalid when supplying a valid format but server does not have MX records" do
      params = %{email: "test@nomxrecords.mbta.com"}
      changeset = Changeset.cast(@data, params, :email)
      result = Changeset.validate_email(changeset, :email)
      assert result.errors == %{email: ["has invalid format"]}
      assert result.valid? == false
    end

    test "marks as valid when supplying a real address on a popular domain" do
      params = %{email: "test@gmail.com"}
      changeset = Changeset.cast(@data, params, :email)
      result = Changeset.validate_email(changeset, :email)
      assert result.errors == %{}
      assert result.valid? == true
    end

    test "marks as valid when supplying a real address on the mbta domain" do
      params = %{email: "test@mbta.com"}
      changeset = Changeset.cast(@data, params, :email)
      result = Changeset.validate_email(changeset, :email)
      assert result.errors == %{}
      assert result.valid? == true
    end

    test "marks as valid when supplying a real address with a plus on the mbta domain" do
      params = %{email: "test+test@mbta.com"}
      changeset = Changeset.cast(@data, params, :email)
      result = Changeset.validate_email(changeset, :email)
      assert result.errors == %{}
      assert result.valid? == true
    end
  end

  describe "validate_length/3" do
    setup do
      params = %{password: "password"}
      changeset = Changeset.cast(@data, params, :password)
      {:ok, %{changeset: changeset}}
    end

    test "checks min length", %{changeset: changeset} do
      result = Changeset.validate_length(changeset, :password, min: 10)
      assert result.errors == %{password: ["should be at least 10 character(s)"]}
      refute result.valid?

      result = Changeset.validate_length(changeset, :password, min: 5)
      assert result.errors == %{}
      assert result.valid?
    end

    test "checks max length", %{changeset: changeset} do
      result = Changeset.validate_length(changeset, :password, max: 6)
      assert result.errors == %{password: ["should be at most 6 character(s)"]}
      refute result.valid?

      result = Changeset.validate_length(changeset, :password, max: 10)
      assert result.errors == %{}
      assert result.valid?
    end

    test "checks is length", %{changeset: changeset} do
      result = Changeset.validate_length(changeset, :password, is: 6)
      assert result.errors == %{password: ["should be 6 character(s)"]}
      refute result.valid?

      result = Changeset.validate_length(changeset, :password, is: 8)
      assert result.errors == %{}
      assert result.valid?
    end
  end

  test "put_change/3" do
    changeset = %Changeset{changes: %{name: "foo"}}
    assert %Changeset{changes: %{name: "bar"}} = Changeset.put_change(changeset, :name, "bar")
  end
end
