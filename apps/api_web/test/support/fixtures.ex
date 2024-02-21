defmodule ApiWeb.Fixtures do
  @moduledoc false

  @test_password "password"
  @valid_user_attrs %{
    email: "authorized@example.com",
    password: @test_password
  }

  def fixture(:totp_user) do
    time = DateTime.utc_now() |> DateTime.add(-35, :second)
    {:ok, user} = ApiAccounts.create_user(@valid_user_attrs)
    {:ok, user} = ApiAccounts.generate_totp_secret(user)

    {:ok, user} =
      ApiAccounts.enable_totp(
        user,
        NimbleTOTP.verification_code(user.totp_secret_bin, time: time),
        time: time
      )

    user
  end
end
