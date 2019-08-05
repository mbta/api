defmodule ApiWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  imports other functionality to make it easier
  to build and query models.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate
  import Plug.Conn

  using do
    quote do
      # Import conveniences for testing with connections
      use Phoenix.ConnTest
      use PhoenixSwagger.SchemaTest, ApiWeb.swagger_path()
      import ApiWeb.ConnCase
      import ApiWeb.Router.Helpers

      # The default endpoint for testing
      @endpoint ApiWeb.Endpoint
    end
  end

  setup _tags do
    conn = conn_with_api_key(Phoenix.ConnTest.build_conn())
    {:ok, conn: conn}
  end

  def conn_with_api_key(%Plug.Conn{} = conn) do
    valid_key = %ApiAccounts.Key{key: String.duplicate("v", 32), approved: true}
    ApiAccounts.Keys.cache_key(valid_key)
    ApiWeb.RateLimiter.force_clear()
    api_version = Enum.max(Application.get_env(:api_web, :versions)[:versions])

    conn
    |> assign(:api_key, valid_key.key)
    |> assign(:api_version, api_version)
  end

  @doc """
  Adds usable session storage to a conn.
  """
  @spec conn_with_session(Plug.Conn.t()) :: Plug.Conn.t()
  def conn_with_session(%Plug.Conn{} = conn) do
    session_opts =
      Plug.Session.init(
        store: :cookie,
        key: "_api_key",
        signing_salt: Application.get_env(:api_web, :signing_salt)
      )

    conn
    |> Plug.Session.call(session_opts)
    |> Plug.Conn.fetch_session()
  end

  @doc """
  Adds a user to the session.
  """
  @spec conn_with_user(Plug.Conn.t(), ApiAccounts.User.t()) :: Plug.Conn.t()
  def conn_with_user(conn, %ApiAccounts.User{id: user_id} = user) do
    conn
    |> Plug.Conn.put_session(:user_id, user_id)
    |> Plug.Conn.assign(:user, user)
  end

  @doc """
  Adds content type for URL encoded forms to conn.
  """
  def form_header(conn) do
    put_req_header(conn, "content-type", "application/x-www-form-urlencoded")
  end

  @doc """

  """
  def setup_key_requesting_user(%{conn: conn}) do
    on_exit(&ApiAccounts.Dynamo.delete_all_tables/0)

    ApiAccounts.Dynamo.create_table(ApiAccounts.User)
    ApiAccounts.Dynamo.create_table(ApiAccounts.Key)

    {:ok, user} = ApiAccounts.create_user(%{email: "test@test"})
    # MUST be setup to receive email about key requests
    {:ok, _} = ApiAccounts.create_user(%{email: "admin@test", role: "administrator"})

    conn =
      conn
      |> conn_with_session()
      |> conn_with_user(user)

    {:ok, user: user, conn: conn}
  end
end
