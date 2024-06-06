excludes = [:integration]

# try to connect to memcache: if it fails, don't run those tests
excludes =
  case :gen_tcp.connect(~c"localhost", 11_211, [:inet], 100) do
    {:ok, sock} ->
      :gen_tcp.close(sock)
      excludes

    {:error, _} ->
      [:memcache | excludes]
  end

ExUnit.start(exclude: excludes)

defmodule ApiWeb.Test.ProcessHelper do
  use ExUnit.Case

  def assert_stopped(pid) do
    if Process.alive?(pid) do
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}
    else
      :ok
    end
  end
end
