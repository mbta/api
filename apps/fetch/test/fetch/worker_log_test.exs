defmodule Fetch.WorkerLogTest do
  use ExUnit.Case
  import ExUnit.CaptureLog, only: [capture_log: 1]

  import Plug.Conn

  setup do
    bypass = Bypass.open()
    url = "http://localhost:#{bypass.port}"
    {:ok, pid} = Fetch.Worker.start_link(url)
    {:ok, %{bypass: bypass, pid: pid, url: url}}
  end

  test "logs a fetch timeout as a warning", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn conn ->
      Process.sleep(1000)

      conn
      |> resp(200, "body")
    end)

    assert capture_log(fn ->
             Fetch.Worker.fetch_url(pid, timeout: 100)
           end) =~ "[warn]"

    Bypass.pass(bypass)
  end

  test "logs an unknown error as an error", %{bypass: bypass, pid: pid} do
    Bypass.expect(bypass, fn _conn ->
      raise "Oops"
    end)

    assert capture_log(fn ->
             Fetch.Worker.fetch_url(pid, timeout: 100)
           end) =~ "[error]"

    Bypass.pass(bypass)
  end
end
