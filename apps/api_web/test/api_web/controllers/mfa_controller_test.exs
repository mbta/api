defmodule ApiWeb.MfaControllerTest do
  @moduledoc false
  use ApiWeb.ConnCase, async: false

  alias ApiWeb.Fixtures

  setup %{conn: conn} do
    ApiAccounts.Dynamo.create_table(ApiAccounts.User)
    on_exit(fn -> ApiAccounts.Dynamo.delete_all_tables() end)
    {:ok, conn: conn}
  end

  test "2fa redirects user on success", %{conn: conn} do
    user = Fixtures.fixture(:totp_user)

    conn =
      conn
      |> conn_with_session()
      |> put_session(:inc_user_id, user.id)
      |> put_session(:destination, portal_path(conn, :index))

    conn =
      post(
        form_header(conn),
        mfa_path(conn, :create),
        user: %{totp_code: NimbleTOTP.verification_code(user.totp_secret_bin)}
      )

    assert redirected_to(conn) == portal_path(conn, :index)
  end

  test "2fa does not accept invalid codes", %{conn: conn} do
    user = Fixtures.fixture(:totp_user)

    conn = conn |> conn_with_session() |> put_session(:inc_user_id, user.id)

    conn =
      post(
        form_header(conn),
        mfa_path(conn, :create),
        user: %{totp_code: "1234"}
      )

    assert html_response(conn, 200) =~ "TOTP"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) != nil
  end
end
