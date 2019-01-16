defmodule ApiAccounts.Notifications do
  @moduledoc """
  Sends account-related notifications to users.
  """
  alias ApiAccounts.{Key, Mailer, User}
  import Bamboo.Email

  def send_key_requested(administrators, %User{} = user, url) do
    text = """
    A user has requested a new API key.

    ID: #{user.id}
    Email: #{user.email}
    URL: #{url}
    """

    administrator_emails = for admin <- administrators, do: admin.email

    base_email()
    |> subject("New Key Request: #{user.email}")
    |> to(administrator_emails)
    |> text_body(text)
    |> Mailer.deliver_now()
  end

  def send_limit_increase_requested(administrators, %User{} = user, %Key{} = key, url, reason) do
    splunk_url =
      "https://mbta.splunkcloud.com/en-US/app/search/search?q=search%20index%3Dapi-*-application%20api_key%3D#{
        key.key
      }&display.page.search.mode=verbose&dispatch.sample_ratio=1&earliest=-24h%40h&latest=now"

    text = """
    A user has requested a rate-limit increase.

    Key: #{key.key}
    User ID: #{key.user_id}
    Email: #{user.email}
    URL: #{url}
    Last 24h usage: #{splunk_url}
    Reason for request: #{reason}
    """

    administrator_emails = for admin <- administrators, do: admin.email

    base_email()
    |> subject("Key Limit Increase Request: #{user.email}")
    |> to(administrator_emails)
    |> text_body(text)
    |> Mailer.deliver_now()
  end

  def send_password_reset(%User{email: email}, recovery_url) do
    text =
      "A request has been made to reset your password.\n\n" <>
        "Use the following link to change your password:\n\n" <> recovery_url

    base_email()
    |> subject("Password Reset Request")
    |> to(email)
    |> text_body(text)
    |> Mailer.deliver_now()
  end

  def send_key_request_approved(%User{email: email}, %Key{} = key, portal_url) do
    text = """
    Your request for a new API key has been approved.

    Key: #{key.key}

    Visit #{portal_url} to check out documentation and other information.
    """

    base_email()
    |> subject("API Key Request Approved")
    |> to(email)
    |> text_body(text)
    |> Mailer.deliver_now()
  end

  def send_key_request_rejected(%User{email: email}) do
    text = "Your request for a new API key has been rejected."

    base_email()
    |> subject("API Key Request Rejected")
    |> to(email)
    |> text_body(text)
    |> Mailer.deliver_now()
  end

  defp base_email do
    new_email(from: {"MBTA Support", "developer@mbta.com"})
  end
end
