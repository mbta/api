defmodule ApiAccounts do
  @moduledoc """
  Stores and identifies API consumer accounts and keys.
  """

  alias ApiAccounts.{Changeset, Dynamo, Key, NoResultsError, User}

  @default_version Application.get_env(:api_web, :versions)[:default]

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  @spec list_users() :: [User.t()]
  def list_users do
    Dynamo.scan(User)
  end

  @doc """
  Returns the list of administrators.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  @spec list_administrators() :: [User.t()]
  def list_administrators do
    Enum.filter(list_users(), &(&1.role == "administrator"))
  end

  @doc """
  Gets a single user.

  Raises if the User does not exist.

  ## Examples

      iex> get_user!("UNIQUEID")
      %User{...}

  """
  @spec get_user!(String.t()) :: User.t() | no_return
  def get_user!(id) do
    case get_user(id) do
      {:ok, user} ->
        user

      {:error, :not_found} ->
        raise NoResultsError, "A User with the id #{id} was not found."
    end
  end

  @doc """
  Gets a single user.

  ## Examples

      iex> get_user("UNIQUEID")
      {:ok, %User{...}}

      iex> get_user("bad_id")
      {:error, :not_found}

  """
  @spec get_user(String.t()) :: {:ok, User.t()} | {:error, :not_found}
  def get_user(id) do
    Dynamo.fetch_item(User, %{id: id})
  end

  @doc """
  Gets a single user by email address.

  Fetching a user using a map is solely intended for use with the client portal.

  ## Examples

      iex> get_user_by_email("test@test.com")
      {:ok, %User{...}}

      iex> get_user_by_email("bad@test.com")
      {:error, :not_found}

      iex> get_user_by_email(%{email: "test@test.com"})
      {:ok, %User{...}}

      iex> get_user_by_email(%{email: "bad_addr"})
      {:error, %Changeset{...}}

  """
  @spec get_user_by_email(String.t()) :: {:ok, User.t()} | {:error, :not_found}
  def get_user_by_email(email) when is_binary(email) do
    User
    |> Dynamo.query("email = :email", %{email: email}, index_name: "email_secondary_index")
    |> Enum.at(0)
    |> case do
      user = %User{} -> {:ok, user}
      _ -> {:error, :not_found}
    end
  end

  @spec get_user_by_email(map) :: {:ok, User.t()} | {:error, Changeset.t()} | {:error, :not_found}
  def get_user_by_email(params) when is_map(params) do
    case User.account_recovery(params) do
      %Changeset{valid?: true, changes: changes} ->
        get_user_by_email(changes.email)

      changeset ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a single user by email address.

  Raises if user isn't found.

  ## Examples

    iex> get_user_by_email!("test@test.com")
    %User{...}

  """
  def get_user_by_email!(email) do
    case get_user_by_email(email) do
      {:ok, user} ->
        user

      {:error, :not_found} ->
        raise NoResultsError, "A User with the email #{email} was not found."
    end
  end

  @doc """
  Creates a user.

  This should be used internally or by administrators.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, ...}

  """
  @spec create_user(map) :: {:ok, User.t()} | {:error, Changeset.t()} | {:error, any}
  def create_user(attrs \\ %{}) do
    case User.new(%User{}, attrs) do
      %Changeset{valid?: true} = changeset -> Dynamo.put_item(changeset)
      changeset -> {:error, changeset}
    end
  end

  @doc """
  Creates a new user account.

  Intended to be invoked by a registration form.
  """
  @spec register_user(map) :: {:ok, User.t()} | {:error, Changeset.t()} | {:error, any}
  def register_user(attrs \\ %{}) do
    case User.register(%User{}, attrs) do
      %Changeset{valid?: true} = changeset -> Dynamo.put_item(changeset)
      changeset -> {:error, changeset}
    end
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, ...}

  """
  def update_user(%User{} = user, attrs \\ %{}) do
    case User.update(user, attrs) do
      %Changeset{valid?: true} = changeset -> Dynamo.update_item(changeset)
      changeset -> {:error, changeset}
    end
  end

  @doc """
  Deletes a User.

  Any keys belonging to the user will also be deleted.

  ## Examples

      iex> delete_user(user)
      :ok

      iex> delete_user(user)
      {:error, ...}

  """
  @spec delete_user(User.t()) :: :ok | {:error, any}
  def delete_user(%User{} = user) do
    with :ok <- Dynamo.delete_item(user) do
      user
      |> list_keys_for_user()
      |> Task.async_stream(&delete_key/1)
      |> Stream.run()
    end
  end

  @doc """
  Returns a datastructure for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Changeset{...}

  """
  def change_user(%User{} = user) do
    Changeset.change(user)
  end

  @doc """
  Creates a new Key for a given user.

  ## Examples

      iex> create_key(user)
      {:ok, %Key{...}}

      iex> create_key(user, %{approved: true})
      {:ok, %Key{...}}

  """
  @spec create_key(User.t()) :: {:ok, Key.t()} | {:error, any}
  @spec create_key(User.t(), map) :: {:ok, Key.t()} | {:error, any}
  def create_key(%User{id: id}, params \\ %{}) when is_map(params) do
    api_key = UUID.uuid4(:hex)
    now = DateTime.utc_now()
    version = @default_version
    key = %Key{key: api_key, api_version: version, user_id: id, created: now, requested_date: now}
    key = struct!(key, params)
    Dynamo.put_item(key)
  end

  @doc """
  Fetches a single api key.

  ## Examples

      iex> get_key("valid-key")
      {:ok, %Key{...}}

      iex> get_key("bad-id")
      {:error, :not_found}

  """
  @spec get_key(String.t()) :: {:ok, Key.t()} | {:error, :not_found}
  def get_key(key_id) do
    Dynamo.fetch_item(Key, %{key: key_id})
  end

  @doc """
  Fetches a single api key for a user.

  ## Examples

      iex> get_key("user-id", "valid-key")
      {:ok, %Key{...}}

      iex> get_key("user-id", "bad-id")
      {:error, :not_found}

      iex> get_key("other-user", "valid-key")
      {:error, :not_found}

  """
  @spec get_key(String.t(), String.t()) :: {:ok, Key.t()} | {:error, :not_found}
  def get_key(user_id, key_id) do
    case Dynamo.fetch_item(Key, %{key: key_id}) do
      {:ok, %{user_id: ^user_id}} = result ->
        result

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Fetches a single api key.

  Raises if the Key is not found.

  ## Examples

      iex> get_key("valid-key")
      %Key{...}

  """
  @spec get_key!(String.t()) :: Key.t() | no_return
  def get_key!(key_id) do
    case get_key(key_id) do
      {:ok, key} ->
        key

      {:error, :not_found} ->
        raise NoResultsError, "A Key with the id #{key_id} was not found."
    end
  end

  @doc """
  Fetches a single API key for a user.

  Raises if the key is not found, or doesn't exist for the user ID.
  """
  @spec get_key!(String.t(), String.t()) :: Key.t() | no_return
  def get_key!(user_id, key_id) do
    case get_key(user_id, key_id) do
      {:ok, key} ->
        key

      {:error, :not_found} ->
        raise NoResultsError, "A Key with the id #{key_id} and user_id #{user_id} was not found."
    end
  end

  @doc """
  Deletes an Api key.

  ## Examples

      iex> delete_key(key)
      :ok

      iex> delete_key(key)
      {:error, ...}

  """
  @spec delete_key(Key.t()) :: :ok | {:error, any}
  def delete_key(%Key{} = key) do
    Dynamo.delete_item(key)
  end

  @doc """
  Retrieves any keys belonging to a user.

  ## Examples

      iex> list_keys_for_user(user)
      [%Key{...}, ...]

  """
  @spec list_keys_for_user(User.t()) :: [Key.t()]
  def list_keys_for_user(%User{id: id}) do
    Dynamo.query(Key, "user_id = :id", %{id: id}, index_name: "user_id_secondary_index")
  end

  @doc """
  Requests a new key for a user.

  A user can only request one key at a time.

  ## Examples

      iex> request_key(user)
      {:ok, %Key{...}}

      iex> request_key(user)
      :error

  """
  @spec request_key(User.t()) :: {:ok, Key.t()} | :error
  def request_key(%User{} = user) do
    if can_request_key?(user) do
      auto_approve? = auto_approve_key?(user)

      create_key(user, %{approved: auto_approve?})
    else
      :error
    end
  end

  @doc """
  Returns whether a user can request a new API key.

  ## Examples

      iex> can_request_key(%User{...})
      true

      iex> can_request_key?([%Key{...}, %Key{...}])
      false

  """
  @spec can_request_key?(User.t()) :: boolean
  def can_request_key?(%User{} = user) do
    user
    |> list_keys_for_user()
    |> can_request_key?()
  end

  @spec can_request_key?([Key.t()]) :: boolean
  def can_request_key?(keys) when is_list(keys) do
    keys
    |> Enum.filter(&(not &1.approved))
    |> Enum.empty?()
  end

  @doc """
  Returns whether the key should be automatically approved for the user.
  """
  @spec auto_approve_key?(User.t()) :: boolean
  def auto_approve_key?(%User{} = user) do
    # if there are no other keys, approve this one
    user
    |> list_keys_for_user
    |> Enum.empty?()
  end

  @doc """
  Returns a datastructure for tracking key changes.

  ## Examples

      iex> change_key(key)
      %Changeset{...}

  """
  def change_key(%Key{} = key) do
    Changeset.change(key)
  end

  @doc """
  Updates a key.

  ## Examples

      update_key(key, %{approved: true})

  """
  @spec update_key(Key.t(), map) :: {:ok, Key.t()} | {:error, Changeset.t()} | {:error, any}
  def update_key(%Key{} = key, updates \\ %{}) when is_map(updates) do
    case Key.changeset(key, updates) do
      %Changeset{valid?: true} = changeset -> Dynamo.update_item(changeset)
      changeset -> {:error, changeset}
    end
  end

  @doc """
  Fetches all key requests requiring approval.

  Results are sorted by oldest request date first.
  """
  @spec list_key_requests() :: [{Key.t(), User.t()}]
  def list_key_requests do
    keys =
      Key
      |> Dynamo.scan("approved = :approved", %{approved: false})
      |> Enum.sort_by(& &1.requested_date)

    users =
      keys
      |> Enum.map(&Task.async(fn -> get_user!(&1.user_id) end))
      |> Task.yield_many()
      |> Enum.map(fn {_task, {:ok, user}} -> user end)

    Enum.zip(keys, users)
  end

  @doc """
  Authenticates and validates user credentials.

  If a user is found by email address, the password will be validated against
  the stored hashed password.

  ## Examples

      iex> authenticate(%{email: "test@test.com", password: "password"})
      {:ok, %User{...}}

      iex> authenticate(%{email: "test@test.com", password: "wrong_password"})
      {:error, :invalid_credentials}

      iex> authenticate(%{email: "bad_id", password: "password"})
      {:error, :invalid_credentials}

      iex> authenticate(%{})
      {:error, %Changeset{...}}

  """
  @spec authenticate(map) ::
          {:ok, User.t()} | {:error, Changeset.t()} | {:error, :invalid_credentials}
  def authenticate(credentials) when is_map(credentials) do
    with %Changeset{valid?: true} = changeset <- User.authenticate(%User{}, credentials),
         %{email: email, password: password} = changeset.changes,
         {:ok, user} <- get_user_by_email(email),
         true <- Bcrypt.verify_pass(password, user.password) do
      {:ok, user}
    else
      %Changeset{valid?: false} = changeset ->
        {:error, changeset}

      {:error, :not_found} ->
        # Do a dummy check to prevent timing-based attacks
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      _ ->
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Updates a user's password.
  """
  @spec update_password(User.t(), map) :: {:ok, User.t()} | {:error, Changeset.t()}
  def update_password(%User{} = user, params) when is_map(params) do
    case User.update_password(user, params) do
      %Changeset{valid?: true} = changeset -> Dynamo.update_item(changeset)
      changeset -> {:error, changeset}
    end
  end

  @doc """
  Updates a user's account information.
  """
  @spec update_information(User.t(), map) :: {:ok, User.t()} | {:error, Changeset.t()}
  def update_information(%User{} = user, params) when is_map(params) do
    case User.restricted_update(user, params) do
      %Changeset{valid?: true} = changeset -> Dynamo.update_item(changeset)
      changeset -> {:error, changeset}
    end
  end
end
