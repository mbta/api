defmodule Fetch.WorkerLogTest do
  use ExUnit.Case
  import ExUnit.CaptureLog, only: [capture_log: 1]

  import Plug.Conn

  setup do
    lasso = Lasso.open()
    url = "http://localhost:#{lasso.port}"
    {:ok, pid} = Fetch.Worker.start_link(url)
    {:ok, %{lasso: lasso, pid: pid, url: url}}
  end

  test "logs a fetch timeout as a warning", %{lasso: lasso, pid: pid} do
    Lasso.expect(lasso, "GET", "/", fn conn ->
      Process.sleep(1000)

      conn
      |> resp(200, "body")
    end)

    assert capture_log(fn ->
             Fetch.Worker.fetch_url(pid, timeout: 100)
           end) =~ "[warning]"
  end

  test "logs an unknown error as an error", %{lasso: lasso, pid: pid} do
    Lasso.expect(lasso, "GET", "/", fn conn ->
      conn
      |> resp(500, "")
    end)

    assert capture_log(fn ->
             Fetch.Worker.fetch_url(pid, timeout: 100)
           end) =~ "[error]"
  end
end
