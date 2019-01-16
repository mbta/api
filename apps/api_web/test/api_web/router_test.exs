defmodule ApiWeb.RouterTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import ApiWeb.Router
  import Phoenix.ConnTest

  describe "authenticated_accepts/2" do
    test "denies anonymous users when the type is in authenticated_accepts" do
      conn =
        build_conn()
        |> Map.put(:req_headers, [{"accept", "text/event-stream"}])
        |> accepts_runtime([])
        |> ApiWeb.Plugs.Authenticate.call(ApiWeb.Plugs.Authenticate.init([]))

      assert_raise Phoenix.NotAcceptableError, fn ->
        authenticated_accepts(conn, ["event-stream"])
      end
    end

    test "allows registered users when the type is in authenticated_accepts" do
      assert %Plug.Conn{} =
               build_conn()
               |> ApiWeb.ConnCase.conn_with_api_key()
               |> Map.put(:req_headers, [{"accept", "text/event-stream"}])
               |> accepts_runtime([])
               |> ApiWeb.Plugs.Authenticate.call(ApiWeb.Plugs.Authenticate.init([]))
               |> authenticated_accepts(["event-stream"])
    end

    test "allows anonymous users when the type isn't in authenticated_accepts" do
      assert %Plug.Conn{} =
               build_conn()
               |> Map.put(:req_headers, [{"accept", "text/event-stream"}])
               |> accepts_runtime([])
               |> ApiWeb.Plugs.Authenticate.call(ApiWeb.Plugs.Authenticate.init([]))
               |> authenticated_accepts([])

      assert %Plug.Conn{} =
               build_conn()
               |> Map.put(:req_headers, [{"accept", "application/json"}])
               |> accepts_runtime([])
               |> ApiWeb.Plugs.Authenticate.call(ApiWeb.Plugs.Authenticate.init([]))
               |> authenticated_accepts(["event-stream"])
    end
  end
end
