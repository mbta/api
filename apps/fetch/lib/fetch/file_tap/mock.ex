defmodule Fetch.FileTap.MockTap do
  @moduledoc "Mock FileTap which sends a message rather than logging."

  def start_link do
    Registry.start_link(keys: :duplicate, name: __MODULE__)
  end

  @doc "Register to be notified of logs"
  def register! do
    ref = make_ref()
    {:ok, _pid} = Registry.register(__MODULE__, :log_body, ref)
    {:ok, ref}
  end

  def log_body(url, body, fetch_dt) do
    Registry.dispatch(__MODULE__, :log_body, fn entries ->
      for {pid, ref} <- entries do
        send(pid, {:log_body, ref, url, body, fetch_dt})
      end
    end)
  end
end
