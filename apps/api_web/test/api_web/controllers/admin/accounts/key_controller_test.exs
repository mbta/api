defmodule ApiWeb.Admin.Accounts.KeyControllerTest do
  use ApiWeb.ConnCase
  use Bamboo.Test, shared: true

  setup %{conn: conn} do
    ApiAccounts.Dynamo.create_table(ApiAccounts.User)
    ApiAccounts.Dynamo.create_table(ApiAccounts.Key)

    on_exit(fn -> ApiAccounts.Dynamo.delete_all_tables() end)

    {:ok, user} =
      ApiAccounts.create_user(%{
        email: "test@example.com",
        role: "administrator",
        totp_enabled: true
      })

    {:ok, user} = ApiAccounts.generate_totp_secret(user)
    ApiAccounts.enable_totp(user, NimbleTOTP.verification_code(user.totp_secret_bin))

    conn =
      conn
      |> conn_with_session()
      |> conn_with_user(user)

    {:ok, conn: conn, user: user}
  end

  test "creates a key and redirects", %{conn: conn, user: user} do
    conn = post(form_header(conn), admin_key_path(conn, :create, user))
    assert redirected_to(conn) == admin_user_path(conn, :show, user)
    assert [key] = ApiAccounts.list_keys_for_user(user)
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ key.key
    assert key.approved
    assert key.created
    assert key.requested_date
  end

  test "deletes a key and redirects", %{conn: base_conn, user: user} do
    {:ok, key} = ApiAccounts.create_key(user)
    ApiAccounts.Keys.cache_key(key)
    {:ok, _} = ApiAccounts.Keys.fetch_valid_key(key.key)

    conn = delete(form_header(base_conn), admin_key_path(base_conn, :delete, user, key))
    assert redirected_to(conn) == admin_user_path(conn, :show, user)

    assert_error_sent(:not_found, fn ->
      delete(form_header(base_conn), admin_key_path(conn, :delete, user, key))
    end)

    assert ApiAccounts.list_keys_for_user(user) == []
    assert {:error, :not_found} == ApiAccounts.Keys.fetch_valid_key(key.key)
  end

  test "rejects key and redirects", %{conn: base_conn, user: user} do
    {:ok, key} = ApiAccounts.create_key(user)
    ApiAccounts.Keys.cache_key(key)
    {:ok, _} = ApiAccounts.Keys.fetch_valid_key(key.key)

    conn =
      base_conn
      |> form_header()
      |> delete(admin_key_path(base_conn, :delete, user, key, action: "reject"))

    assert redirected_to(conn) == admin_user_path(conn, :show, user)

    # Make sure notification email is sent
    assert_received {:delivered_email, _}

    # can't delete the same key
    assert_error_sent(:not_found, fn ->
      delete(form_header(base_conn), admin_key_path(conn, :delete, user, key))
    end)

    assert ApiAccounts.list_keys_for_user(user) == []
    assert {:error, :not_found} == ApiAccounts.Keys.fetch_valid_key(key.key)
  end

  test "approves a key and redirects", %{conn: base_conn, user: user} do
    {:ok, key} = ApiAccounts.request_key(user)

    conn =
      base_conn
      |> form_header()
      |> put(admin_key_path(base_conn, :approve, user, key))

    assert redirected_to(conn) == admin_user_path(conn, :show, user)
    assert Phoenix.Flash.get(conn.assigns.flash, :info)

    key = ApiAccounts.get_key!(key.key)
    assert key.approved
    assert key.created

    # Make sure notification email is sent
    assert_received {:delivered_email, _}
  end

  test "shows pending key approvals", %{conn: conn} do
    key_requests =
      for i <- 1..5 do
        {:ok, user} = ApiAccounts.create_user(%{email: "test#{i}@example.com"})
        {:ok, key} = ApiAccounts.create_key(user)
        {key, user}
      end

    conn = get(conn, admin_key_path(conn, :index))

    page = html_response(conn, 200)

    for {key, user} <- key_requests do
      assert page =~ key.key
      assert page =~ user.email
    end
  end

  test "renders form for editing a key", %{conn: conn, user: user} do
    {:ok, key} = ApiAccounts.create_key(user)
    conn = get(conn, admin_key_path(conn, :edit, user, key))
    assert html_response(conn, 200) =~ "Edit Key"
  end

  test "can edit the daily limit", %{conn: base_conn, user: user} do
    {:ok, key} = ApiAccounts.create_key(user)
    {:ok, key} = ApiAccounts.update_key(key, %{rate_request_pending: true})
    ApiAccounts.Keys.cache_key(key)

    conn =
      base_conn
      |> form_header()
      |> put(admin_key_path(base_conn, :update, user, key), key: %{daily_limit: "10000"})

    assert redirected_to(conn) == admin_user_path(conn, :show, user)
    assert {:ok, new_key} = ApiAccounts.Keys.fetch_valid_key(key.key)
    assert new_key.daily_limit == 10_000
    refute new_key.rate_request_pending
  end

  test "can edit the daily limit by providing a per-minute limit", %{conn: base_conn, user: user} do
    {:ok, key} = ApiAccounts.create_key(user)
    {:ok, key} = ApiAccounts.update_key(key, %{rate_request_pending: true})
    ApiAccounts.Keys.cache_key(key)

    conn =
      base_conn
      |> form_header()
      |> put(admin_key_path(base_conn, :update, user, key), key: %{per_minute_limit: "10001"})

    assert redirected_to(conn) == admin_user_path(conn, :show, user)
    assert {:ok, new_key} = ApiAccounts.Keys.fetch_valid_key(key.key)
    assert new_key.daily_limit == 10_001 * 60 * 24
    refute Map.has_key?(new_key, :per_minute_limit)
    refute new_key.rate_request_pending
  end

  test "can edit the daily limit by providing a per-minute limit as an integer", %{
    conn: base_conn,
    user: user
  } do
    {:ok, key} = ApiAccounts.create_key(user)
    {:ok, key} = ApiAccounts.update_key(key, %{rate_request_pending: true})
    ApiAccounts.Keys.cache_key(key)

    conn =
      base_conn
      |> form_header()
      |> put(admin_key_path(base_conn, :update, user, key), key: %{per_minute_limit: 10_001})

    assert redirected_to(conn) == admin_user_path(conn, :show, user)
    assert {:ok, new_key} = ApiAccounts.Keys.fetch_valid_key(key.key)
    assert new_key.daily_limit == 10_001 * 60 * 24
    refute Map.has_key?(new_key, :per_minute_limit)
    refute new_key.rate_request_pending
  end

  test "can edit the API version", %{conn: base_conn, user: user} do
    {:ok, key} = ApiAccounts.create_key(user)
    ApiAccounts.Keys.cache_key(key)

    conn =
      base_conn
      |> form_header()
      |> put(admin_key_path(base_conn, :update, user, key), key: %{api_version: "2017-11-28"})

    assert redirected_to(conn) == admin_user_path(conn, :show, user)
    assert {:ok, new_key} = ApiAccounts.Keys.fetch_valid_key(key.key)
    assert new_key.api_version == "2017-11-28"
  end

  test "ignores invalid API versions", %{conn: base_conn, user: user} do
    {:ok, key} = ApiAccounts.create_key(user)
    ApiAccounts.Keys.cache_key(key)

    conn =
      base_conn
      |> form_header()
      |> put(admin_key_path(base_conn, :update, user, key), key: %{api_version: "invalid"})

    assert redirected_to(conn) == admin_user_path(conn, :show, user)
    assert {:ok, new_key} = ApiAccounts.Keys.fetch_valid_key(key.key)
    refute new_key.api_version == "invalid"
  end

  test "daily limit of empty string is nil", %{conn: base_conn, user: user} do
    {:ok, key} = ApiAccounts.create_key(user)
    {:ok, key} = ApiAccounts.update_key(key, %{daily_limit: 5})
    ApiAccounts.Keys.cache_key(key)

    conn =
      base_conn
      |> form_header()
      |> put(admin_key_path(base_conn, :update, user, key), key: %{daily_limit: ""})

    assert redirected_to(conn) == admin_user_path(conn, :show, user)
    assert {:ok, new_key} = ApiAccounts.Keys.fetch_valid_key(key.key)
    assert new_key.daily_limit == nil
  end

  test "does not update the key and render errors with invalid data", %{conn: conn, user: user} do
    {:ok, key} = ApiAccounts.create_key(user)
    {:ok, key} = ApiAccounts.update_key(key, %{approved: true})
    invalid_data = %{daily_limit: "string"}
    conn = put(form_header(conn), admin_key_path(conn, :update, user, key), key: invalid_data)
    response = html_response(conn, 200)
    assert response =~ "Edit Key"
    assert response =~ "something went wrong"
    assert response =~ "not an integer"
    assert {:ok, ^key} = ApiAccounts.Keys.fetch_valid_key(key.key)
  end

  test "redirects to user by id when getting a key by key_id", %{conn: conn, user: user} do
    assert {:ok, key} = ApiAccounts.create_key(user)
    {:ok, key} = ApiAccounts.update_key(key, %{approved: true})
    expected_path = admin_user_path(conn, :show, user)
    request_path = admin_key_path(conn, :redirect_to_user_by_id, key.key)
    conn = get(conn, request_path)
    assert redirected_to(conn) == expected_path
  end

  test "can clone a key", %{conn: base_conn, user: user} do
    {:ok, key} = ApiAccounts.create_key(user)
    {:ok, key} = ApiAccounts.update_key(key, %{approved: true})
    ApiAccounts.Keys.cache_key(key)

    conn =
      base_conn
      |> form_header()
      |> put(admin_key_path(base_conn, :clone, user, key))

    assert redirected_to(conn) == admin_user_path(conn, :show, user)
    # ensure there are now two keys
    assert [_, _] = keys = ApiAccounts.list_keys_for_user(user)
    new_key = Enum.find(keys, &(&1.key != key.key))
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ new_key.key
  end

  describe "find_user_by_key/1" do
    test "redirects to user if key is found", %{conn: conn, user: user} do
      assert {:ok, key} = ApiAccounts.create_key(user)
      {:ok, key} = ApiAccounts.update_key(key, %{approved: true})
      expected_path = admin_user_path(conn, :show, user)
      request_path = admin_key_path(conn, :find_user_by_key, %{search: %{key: key.key}})
      conn = post(conn, request_path)
      assert redirected_to(conn) == expected_path
    end

    test "doesn't redirect to user if no key is found, displays error message", %{conn: conn} do
      key_id = String.duplicate("v", 32)
      expected_path = admin_key_path(conn, :index)
      request_path = admin_key_path(conn, :find_user_by_key, %{search: %{key: key_id}})
      conn = post(conn, request_path)
      assert redirected_to(conn) == expected_path
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end
  end
end
