defmodule ApiWeb.Plugs.ClearMetadata do
  @moduledoc """
  Clear Logger metadata at the start of a new request.

  Bandit is more agressive about re-using processes than Cowboy was, which means we
  can't rely on the old behavior of the Logger metadata being automatically cleared
  when the process is terminated.

  This takes a list of metadata keys to clear.
  """
  @behaviour Plug

  @impl Plug
  def init(keys_to_clear) do
    for key <- keys_to_clear do
      {key, nil}
    end
  end

  @impl Plug
  def call(conn, metadata) do
    _ = Logger.metadata(metadata)

    conn
  end
end
