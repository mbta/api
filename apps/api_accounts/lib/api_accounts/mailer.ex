defmodule ApiAccounts.Mailer do
  @moduledoc """
  Email client to send emails.
  """
  use Bamboo.Mailer, otp_app: :api_accounts
end
