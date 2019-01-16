defmodule Fetch.WorkerTest do
  use ExUnit.Case, async: true

  import Plug.Conn

  @moduletag capture_log: true

  setup do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"
    {:ok, pid} = Fetch.Worker.start_link(url)
    {:ok, %{bypass: bypass, pid: pid, url: url}}
  end

  test "can fetch a URL", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      resp(conn, 200, "body")
    end)

    assert {:ok, "body"} = Fetch.Worker.fetch_url(pid, [])
  end

  test "logs the response", %{bypass: bypass, pid: pid, url: url} do
    Bypass.expect(bypass, fn conn ->
      resp(conn, 200, "body")
    end)

    {:ok, ref} = Fetch.FileTap.MockTap.register!()

    Fetch.Worker.fetch_url(pid, [])

    assert_receive {:log_body, ^ref, ^url, "body", %DateTime{}}
  end

  test "logs the response with the Last modified time", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      conn
      |> put_resp_header("Last-Modified", "Fri, 23 Jun 2017 13:27:18 GMT")
      |> resp(200, "body with modified")
    end)

    {:ok, ref} = Fetch.FileTap.MockTap.register!()

    Fetch.Worker.fetch_url(pid, [])

    assert_receive {:log_body, ^ref, _, "body with modified", %DateTime{} = dt}
    assert %{year: 2017, month: 6, day: 23, hour: 13, minute: 27, second: 18} = dt
  end

  test "does not log a response if the body is too big", %{bypass: bypass, pid: pid} do
    body = String.duplicate("body", 100)

    Bypass.expect(bypass, fn conn ->
      resp(conn, 200, body)
    end)

    {:ok, ref} = Fetch.FileTap.MockTap.register!()
    Fetch.Worker.fetch_url(pid, [])
    refute_receive {:log_body, ^ref, _, ^body, _}
  end

  test "fetching with a 304 returns returns :unmodified", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      resp(conn, 304, "")
    end)

    assert :unmodified = Fetch.Worker.fetch_url(pid, [])
  end

  test "304 and a cache file with required_body: true returns the cache file" do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}/servername"

    {:ok, pid} =
      Fetch.Worker.start_link(
        [cache_directory: "test/fixtures/"],
        url
      )

    Bypass.expect(bypass, fn conn ->
      resp(conn, 304, "")
    end)

    assert {:ok, "\"cache file\"\n"} == Fetch.Worker.fetch_url(pid, require_body: true)

    Bypass.pass(bypass)
  end

  test "fetching that returns the same content returns :unmodified", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      resp(conn, 200, "body")
    end)

    assert {:ok, _} = Fetch.Worker.fetch_url(pid, [])
    assert :unmodified = Fetch.Worker.fetch_url(pid, [])
    assert {:ok, _} = Fetch.Worker.fetch_url(pid, require_body: true)
  end

  test "after a 200 response, stores the etag/last modified and uses them in the next request", %{
    bypass: bypass,
    pid: pid
  } do
    etag = "12345"
    last_modified = "Tue, 28 Jun 2016 19:03:30 GMT"

    Bypass.expect(bypass, fn conn ->
      case get_req_header(conn, "if-none-match") do
        [^etag] ->
          assert get_req_header(conn, "if-modified-since") == [last_modified]
          resp(conn, 304, "")

        [] ->
          assert get_req_header(conn, "if-modified-since") == []

          conn
          |> put_resp_header("ETag", etag)
          |> put_resp_header("Last-Modified", last_modified)
          |> resp(200, "body")
      end
    end)

    refute Fetch.Worker.fetch_url(pid, []) == :unmodified
    assert Fetch.Worker.fetch_url(pid, []) == :unmodified
  end

  test "decodes a 200 response if it's gzip encoded", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      assert get_req_header(conn, "accept-encoding") == ["gzip"]
      body = :zlib.gzip("body")

      conn
      |> put_resp_header("content-encoding", "gzip")
      |> resp(200, body)
    end)

    assert {:ok, "body"} = Fetch.Worker.fetch_url(pid, [])
  end

  test "returns error tuple if there's a 500 response", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "")
    end)

    assert {:error, _} = Fetch.Worker.fetch_url(pid, [])
  end

  test "turns a fetch timeout into an error", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      Process.sleep(1000)
      resp(conn, 200, "body")
    end)

    assert {:error, %{reason: :timeout}} = Fetch.Worker.fetch_url(pid, timeout: 100)

    Bypass.pass(bypass)
  end

  test "turns a GenServer timeout into an error", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      Process.sleep(1000)
      resp(conn, 200, "body")
    end)

    assert {:error, :timeout} = Fetch.Worker.fetch_url(pid, call_timeout: 10)

    Bypass.pass(bypass)
  end

  test "returns :unmodified if times out, but cache file exists" do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}/servername"

    {:ok, pid} =
      Fetch.Worker.start_link(
        [cache_directory: Application.app_dir(:fetch, "test/fixtures/")],
        url
      )

    Bypass.expect(bypass, fn conn ->
      Process.sleep(1000)

      conn
      |> resp(200, "body")
    end)

    assert :unmodified == Fetch.Worker.fetch_url(pid, timeout: 100)

    Bypass.pass(bypass)
  end

  test "returns the cache file on error with :require_body option" do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}/servername"

    {:ok, pid} =
      Fetch.Worker.start_link(
        [cache_directory: "test/fixtures/"],
        url
      )

    Bypass.expect(bypass, fn conn ->
      Process.sleep(1000)

      conn
      |> resp(200, "body")
    end)

    assert {:ok, "\"cache file\"\n"} ==
             Fetch.Worker.fetch_url(pid, timeout: 100, require_body: true)

    Bypass.pass(bypass)
  end

  test "turns a fetch timeout into an error (long)", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      Process.sleep(30_000)

      conn
      |> resp(200, "body")
    end)

    assert {:error, %{reason: :timeout}} = Fetch.Worker.fetch_url(pid, [])

    Bypass.pass(bypass)
  end

  test "can reconnect if the URL is down for a time", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      resp(conn, 200, "body")
    end)

    Bypass.down(bypass)

    assert {:error, _} = Fetch.Worker.fetch_url(pid, [])

    Bypass.up(bypass)

    assert {:ok, "body"} == Fetch.Worker.fetch_url(pid, [])
  end
end
