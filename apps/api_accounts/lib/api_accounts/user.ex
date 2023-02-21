defmodule ApiAccounts.User do
  @moduledoc """
  Representation of a User.
  """

  use ApiAccounts.Table
  import ApiAccounts.Changeset

  @typedoc """
  Primary key for `ApiAccounts.User.t`
  """
  @type id :: String.t()

  table "api_accounts_users" do
    field(:id, :string, primary_key: true)
    field(:email, :string, secondary_index: true)
    field(:username, :string)
    field(:password, :string)
    field(:password_confirmation, :string, virtual: true)
    field(:role, :string)
    field(:phone, :string)
    field(:join_date, :datetime)
    field(:active, :boolean, default: true)
    field(:blocked, :boolean, default: false)
    schema_version(1)
  end

  @doc false
  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    fields = ~w(email username password role phone join_date active blocked)a

    struct
    |> cast(params, fields)
  end

  @doc false
  def new(%__MODULE__{} = struct, params \\ %{}) do
    fields = ~w(email username password role phone join_date active blocked)a

    struct
    |> cast(params, fields)
    |> validate_required(~w(email)a)
    |> hash_password()
    |> put_id()
    |> put_join_date()
  end

  @doc false
  def update(%__MODULE__{} = struct, params \\ %{}) do
    fields = ~w(email username role phone join_date active blocked)a

    struct
    |> cast(params, fields)
    |> validate_not_nil(fields)
  end

  @doc false
  def restricted_update(%__MODULE__{} = struct, params \\ %{}) do
    fields = ~w(email phone)a

    struct
    |> cast(params, fields)
    |> validate_required([:email])
    |> validate_email(:email)
    |> unique_constraint(:email)
    |> format_email()
  end

  @doc false
  def authenticate(%__MODULE__{} = struct, params \\ %{}) do
    fields = ~w(email password)a

    struct
    |> cast(params, fields)
    |> validate_required(fields)
  end

  @doc false
  def register(%__MODULE__{} = struct, params \\ %{}) do
    fields = ~w(email password password_confirmation)a

    struct
    |> cast(params, fields)
    |> validate_required(fields)
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password)
    |> validate_email(:email)
    |> unique_constraint(:email)
    |> format_email()
    |> hash_password()
    |> put_id()
    |> put_join_date()
  end

  @doc false
  def update_password(%__MODULE__{} = struct, params \\ %{}) do
    fields = ~w(password password_confirmation)a

    struct
    |> cast(params, fields)
    |> validate_required(fields)
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password)
    |> hash_password()
  end

  @doc false
  def account_recovery(params \\ %{}) do
    %__MODULE__{}
    |> cast(params, [:email])
    |> validate_required([:email])
    |> validate_email(:email)
    |> format_email()
  end

  defp format_email(%{valid?: false} = changeset), do: changeset

  defp format_email(%{valid?: true, changes: changes} = changeset) do
    formatted_email =
      changes.email
      |> String.downcase()
      |> String.trim()

    put_change(changeset, :email, formatted_email)
  end

  defp hash_password(%{valid?: false} = changeset), do: changeset

  defp hash_password(%{valid?: true, changes: changes} = changeset) do
    password = changes[:password]

    if password != nil do
      hashed_password = Bcrypt.hash_pwd_salt(password)
      put_change(changeset, :password, hashed_password)
    else
      changeset
    end
  end

  defp put_id(%{valid?: false} = changeset), do: changeset

  defp put_id(%{valid?: true} = changeset) do
    unique_id = UUID.uuid4(:hex)
    put_change(changeset, :id, unique_id)
  end

  defp put_join_date(%{valid?: false} = changeset), do: changeset

  defp put_join_date(%{valid?: true} = changeset) do
    if changeset.changes[:join_date] do
      changeset
    else
      join_date = DateTime.utc_now()
      put_change(changeset, :join_date, join_date)
    end
  end
end
