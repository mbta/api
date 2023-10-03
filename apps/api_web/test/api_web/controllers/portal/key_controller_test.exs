defmodule ApiWeb.ClientPortal.KeyControllerTest do
  use ApiWeb.ConnCase, async: false
  use Bamboo.Test, shared: true

  setup :setup_key_requesting_user
  import ApiWeb.ClientPortal.KeyController

  describe "create" do
    test "creates approved key the first time", %{conn: conn, user: user} do
      conn = post(conn, key_path(conn, :create))
      assert Phoenix.Flash.get(conn.assigns.flash, :success)
      assert redirected_to(conn) == portal_path(conn, :index)
      assert [key] = ApiAccounts.list_keys_for_user(user)
      assert key.approved

      # Make sure notification email sent
      assert_received {:delivered_email, _}
    end

    test "creates a requested key the second time", %{conn: conn, user: user} do
      {:ok, _} = ApiAccounts.create_key(user, %{approved: true})
      conn = post(conn, key_path(conn, :create))
      assert Phoenix.Flash.get(conn.assigns.flash, :success)
      assert redirected_to(conn) == portal_path(conn, :index)
      keys = ApiAccounts.list_keys_for_user(user)
      assert Enum.count(keys) == 2
      assert Enum.count(keys, & &1.approved) == 1

      # Make sure notification email sent
      assert_received {:delivered_email, _}
    end

    test "doesn't allow more than 1 request per user", %{conn: conn, user: user} do
      {:ok, _} = ApiAccounts.create_key(user, %{approved: false})
      conn = post(conn, key_path(conn, :create))
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
      assert redirected_to(conn) == portal_path(conn, :index)
      assert Enum.count(ApiAccounts.list_keys_for_user(user)) == 1
    end
  end

  describe "edit" do
    setup :key

    test "includes a changeset for the key", %{conn: conn, key: key} do
      conn = get(conn, key_path(conn, :edit, key))
      assert html_response(conn, 200)
      assert conn.assigns.changeset
    end
  end

  describe "update" do
    setup :key

    test "updates API version and description", %{conn: conn, key: key} do
      {:ok, key} = ApiAccounts.update_key(key, %{api_version: "not_updated"})

      conn =
        put(
          conn,
          key_path(conn, :update, key),
          key: %{"api_version" => "2018-05-07", "description" => "desc"}
        )

      assert redirected_to(conn) == portal_path(conn, :index)
      updated_key = ApiAccounts.get_key!(key.key)
      assert updated_key.api_version == "2018-05-07"
      assert updated_key.description == "desc"
    end

    test "ignores invalid versions", %{conn: conn, key: key} do
      conn = put(conn, key_path(conn, :update, key), key: %{"api_version" => "invalid"})
      assert redirected_to(conn) == portal_path(conn, :index)
      assert ApiAccounts.get_key!(key.key) == key
    end
  end

  describe "request_increase" do
    setup :key

    test "Sends user to page asking for reason for increase", %{conn: conn, key: key} do
      conn = get(conn, key_path(conn, :request_increase, key))
      assert html_response(conn, 200)
    end
  end

  describe "do_request_increase" do
    setup :key

    test "Sends email and sets flag in key", %{conn: conn, key: key} do
      conn =
        post(
          conn,
          key_path(conn, :do_request_increase, key, reason: %{"reason" => "I require more usage"})
        )

      assert redirected_to(conn) == portal_path(conn, :index)
      updated_key = ApiAccounts.get_key!(key.key)
      assert updated_key.rate_request_pending
      assert_received {:delivered_email, _}
    end

    test "Does not send email when rate increase request is already pending", %{
      conn: conn,
      key: key
    } do
      _ = ApiAccounts.update_key(key, %{rate_request_pending: true})

      conn =
        post(
          conn,
          key_path(conn, :do_request_increase, key, reason: %{"reason" => "I require more usage"})
        )

      assert redirected_to(conn) == portal_path(conn, :index)
      refute_received {:delivered_email, _}
    end
  end

  describe "validate_values/1" do
    test "takes the three editable values" do
      vals =
        validate_values(%{
          "description" => "desc",
          "allowed_domains" => "*",
          "bad key" => "foo"
        })

      assert vals == %{:description => "desc", :allowed_domains => "*"}
    end
  end

  def key(%{user: user}) do
    {:ok, key} = ApiAccounts.create_key(user)
    {:ok, key: key}
  end
end
