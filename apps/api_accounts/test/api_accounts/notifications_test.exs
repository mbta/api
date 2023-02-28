defmodule ApiAccounts.NotificationsTest do
  use ExUnit.Case, async: true
  use Bamboo.Test
  alias ApiAccounts.{Key, Notifications, User}

  test "send_password_reset/2" do
    user = %User{email: "test@mbta.com"}
    url = "http://localhost"
    assert_delivered_email(Notifications.send_password_reset(user, url))
  end

  test "send_key_request_rejected/1" do
    user = %User{email: "test@mbta.com"}
    assert_delivered_email(Notifications.send_key_request_rejected(user))
  end

  test "send_key_request_approved/1" do
    user = %User{email: "test@mbta.com"}
    key = %Key{key: "key"}
    url = "http://localhost"
    assert_delivered_email(Notifications.send_key_request_approved(user, key, url))
  end

  test "send_key_requested/3" do
    admins = [%User{email: "admin1@mbta.com"}, %User{email: "admin2@mbta.com"}]
    user = %User{email: "test@mbta.com"}
    url = "http://localhost/"
    assert_delivered_email(Notifications.send_key_requested(admins, user, url))
  end

  test "send_limit_increase_requested/4" do
    admins = [%User{email: "admin1@mbta.com"}, %User{email: "admin2@mbta.com"}]
    user = %User{email: "test@mbta.com"}
    key = %Key{user_id: user.id}
    url = "http://localhost/"
    reason = "My app is too popular"

    assert_delivered_email(
      Notifications.send_limit_increase_requested(admins, user, key, url, reason)
    )
  end
end
