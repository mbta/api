defmodule FetchTest do
  use ExUnit.Case, async: true
  import Plug.Conn

  setup do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"
    {:ok, %{bypass: bypass, url: url}}
  end

  test "can fetch a URL", %{bypass: bypass, url: url} do
    Bypass.expect(bypass, fn conn ->
      etag = "etag"

      case get_req_header(conn, "if-none-match") do
        [^etag] ->
          resp(conn, 304, "")

        [] ->
          conn
          |> put_resp_header("ETag", etag)
          |> resp(200, "body")
      end
    end)

    assert Fetch.fetch_url(url) == {:ok, "body"}
    assert Fetch.fetch_url(url) == :unmodified
  end
end
