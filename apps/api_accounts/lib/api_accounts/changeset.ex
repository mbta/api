defmodule ApiAccounts.Changeset do
  @moduledoc """
  Assists in creating and updating records by applying rules to changes in data.
  """

  alias ApiAccounts.Changeset

  @type t :: %__MODULE__{}

  defstruct source: nil,
            data: %{},
            changes: %{},
            params: %{},
            errors: %{},
            action: nil,
            constraints: [],
            valid?: true

  @doc """
  Creates a base changeset to work from.

  ## Examples

      iex> change(%User{...})
      %Changeset{source: User, data: %User{...}, ...}

  """
  @spec change(map) :: t
  def change(%source{} = data) do
    %Changeset{source: source, data: data}
  end

  @doc """
  Applies the given params as changes for the given data based on the allowed
  set of keys.

  ##Examples

      iex> cast(%User{}, %{email: "test@test.com"}, ~w(email)a)
      %Changeset{changes: %{email: "test@test.com"}, source: User, ...}

  """
  @spec cast(map, %{optional(atom) => term}, [atom]) :: t
  def cast(%mod{} = data, params, allowed) do
    allowed = List.wrap(allowed)
    types = mod.table_info().field_types

    params
    |> Stream.filter(&field_allowed?(&1, allowed))
    |> Stream.map(&atomized_fields/1)
    |> Enum.reduce(change(data), &cast_change(&2, &1, types))
  end

  defp field_allowed?({key, _}, allowed) when is_atom(key) do
    key in allowed
  end

  defp field_allowed?({key, _}, allowed) when is_binary(key) do
    String.to_existing_atom(key) in allowed
  end

  defp atomized_fields({key, value}) when is_binary(key) do
    {String.to_existing_atom(key), value}
  end

  defp atomized_fields({key, _} = pair) when is_atom(key), do: pair

  defp cast_change(changeset, {key, value}, types) do
    type = Map.get(types, key)
    {key, value} = do_cast_field(key, value, type)
    put_in(changeset.changes[key], value)
  rescue
    e in ArgumentError ->
      append_error({key, [e.message]}, %{changeset | valid?: false})
  end

  defp do_cast_field(key, nil, _), do: {key, nil}

  defp do_cast_field(key, value, :boolean)
       when is_binary(value) and value in ["true", "false"] do
    {key, String.to_atom(value)}
  end

  defp do_cast_field(key, value, :boolean) when is_boolean(value) do
    {key, value}
  end

  defp do_cast_field(key, value, :string) when is_binary(value) do
    {key, value}
  end

  defp do_cast_field(key, value, :integer) when is_integer(value) do
    {key, value}
  end

  defp do_cast_field(key, "", :integer) do
    {key, nil}
  end

  defp do_cast_field(key, value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} ->
        {key, integer}

      _ ->
        raise ArgumentError, "not an integer"
    end
  end

  defp do_cast_field(key, %DateTime{} = value, :datetime) do
    {key, value}
  end

  defp do_cast_field(key, %NaiveDateTime{} = value, :datetime) do
    datetime = DateTime.from_naive!(value, "Etc/UTC")
    {key, datetime}
  end

  defp do_cast_field(key, %{} = date, :datetime) do
    case date do
      %{"year" => _, "month" => _, "day" => _, "hour" => _, "minute" => _} ->
        %{
          "year" => year_string,
          "month" => month_string,
          "day" => day_string,
          "hour" => hour_string,
          "minute" => minute_string
        } = date

        year = String.to_integer(year_string)
        month = String.to_integer(month_string)
        day = String.to_integer(day_string)
        hour = String.to_integer(hour_string)
        minute = String.to_integer(minute_string)

        {:ok, datetime} = NaiveDateTime.new(year, month, day, hour, minute, 0)
        {:ok, datetime} = DateTime.from_naive(datetime, "Etc/UTC")
        {key, datetime}

      _ ->
        raise ArgumentError, "invalid date format"
    end
  end

  @doc """
  Validates that one or more fields are present in the changeset.

  ## Examples

      validate_required(changeset, :email)
      validate_required(changeset, [:email, :role])

  """
  @spec validate_required(t, [atom]) :: t
  def validate_required(%Changeset{} = changeset, fields) do
    fields = List.wrap(fields)

    case do_validate_required(changeset.changes, fields) do
      [] ->
        changeset

      errors ->
        errors
        |> Enum.reduce(changeset, &append_error/2)
        |> Map.put(:valid?, false)
    end
  end

  defp do_validate_required(changes, fields) do
    Enum.flat_map(fields, fn field ->
      if Map.has_key?(changes, field) and Map.get(changes, field) != "" do
        []
      else
        [{field, ["is required"]}]
      end
    end)
  end

  @doc """
  Validates that one or more fields do not have `nil` values in the changeset.

  The validation only applies to the changes. If the applied changes are
  `%{email: nil}` in the changeset and the this function is called to check
  that `:email` is not `nil`, the changeset will be marked as invalid and state
  the field can't be `nil`.

  ## Examples

      validate_not_nil(changeset, :email)
      validate_not_nil(changeset, [:email, :role])

  """
  @spec validate_not_nil(t, [atom]) :: t
  def validate_not_nil(%Changeset{} = changeset, fields) do
    fields = List.wrap(fields)

    case do_validate_not_nil(changeset.changes, fields) do
      [] ->
        changeset

      errors ->
        errors
        |> Enum.reduce(changeset, &append_error/2)
        |> Map.put(:valid?, false)
    end
  end

  defp do_validate_not_nil(changes, fields) do
    Enum.flat_map(changes, fn {field, v} ->
      if field in fields and v == nil do
        [{field, ["cannot be nil"]}]
      else
        []
      end
    end)
  end

  @doc """
  Validates that confirmation field value matches the field value.

  If you were to call `validate_confirmation(changeset, :password)`, then
  the changeset values for `:password` and `:password_confirmation` would be
  checked for equality.

  ## Examples

      validate_confirmation(changeset, :password)

  """
  @spec validate_confirmation(t, atom) :: t
  def validate_confirmation(%Changeset{changes: changes} = changeset, field) do
    confirmation_field = String.to_existing_atom("#{field}_confirmation")
    field_value = Map.get(changes, field)
    confirmation_field_value = Map.get(changes, confirmation_field)

    if field_value == confirmation_field_value do
      changeset
    else
      {confirmation_field, ["does not match #{field}"]}
      |> append_error(changeset)
      |> Map.put(:valid?, false)
    end
  end

  @doc """
  Adds a unique constraint on the field.

  The constraint will be checked right before insertion/update. The contraint
  assumes that the field is a secondary index.

  ## Examples

      unique_constraint(changeset, :email)

  """
  @spec unique_constraint(t, atom) :: t
  def unique_constraint(%Changeset{} = changeset, field) do
    constraints = changeset.constraints

    constraint = %{
      field: field,
      type: :unique,
      message: "has already been taken"
    }

    put_in(changeset.constraints, constraints ++ [constraint])
  end

  @doc """
  Validates the email using jshmrtn/email_checker

  ## Examples

      validate_email(changeset, :email)

  """
  @spec validate_email(t, atom) :: t
  def validate_email(%Changeset{} = changeset, field) do
    value = Map.get(changeset.changes, field, "")
    validation = EmailChecker.valid?(value)

    if validation do
      changeset
    else
      {field, ["has invalid format"]}
      |> append_error(changeset)
      |> Map.put(:valid?, false)
    end
  end

  @doc """
  Validates the length of a field.

  Only Strings are supported.

  ## Options

    * `:min` - length must be greater than or equal to this value
    * `:max` - length must be less than or equal to this value
    * `:is` - length must be exactly this value

  ## Examples

      validate_length(changeset, :email, min: 8)
      validate_length(changeset, :email, max: 32)
      validate_length(changeset, :email, min: 8, max: 32)
      validate_length(changeset, :phone, is: 10)

  """
  @spec validate_length(t, atom, Keyword.t()) :: t
  def validate_length(%Changeset{changes: changes} = changeset, field, opts) do
    field_value = Map.get(changes, field, "")
    length = String.length(field_value)

    error =
      ((is = opts[:is]) && wrong_length(length, is)) ||
        ((min = opts[:min]) && too_short(length, min)) ||
        ((max = opts[:max]) && too_long(length, max))

    if error do
      {field, [error]}
      |> append_error(changeset)
      |> Map.put(:valid?, false)
    else
      changeset
    end
  end

  defp wrong_length(length, length), do: nil

  defp wrong_length(_, length) do
    "should be #{length} character(s)"
  end

  defp too_short(length, min) when length >= min, do: nil

  defp too_short(_, min) do
    "should be at least #{min} character(s)"
  end

  defp too_long(length, max) when length <= max, do: nil

  defp too_long(_, max) do
    "should be at most #{max} character(s)"
  end

  @doc false
  def append_error({field, error}, changeset) do
    case Map.get(changeset.errors, field) do
      nil -> put_in(changeset.errors[field], error)
      list -> put_in(changeset.errors[field], list ++ error)
    end
  end

  @doc """
  Sets a value in the changes for a given key.

  ## Examples

      iex> changeset = User.changeset(%User{}, %{username: "foo"})
      iex> changeset = put_change(changeset, :username, "bar")
      iex> changeset.changes
      %{username: "bar"}

  """
  @spec put_change(t, atom, any) :: t
  def put_change(%Changeset{} = changeset, field, value) when is_atom(field) do
    changes = Map.put(changeset.changes, field, value)
    %Changeset{changeset | changes: changes}
  end
end
