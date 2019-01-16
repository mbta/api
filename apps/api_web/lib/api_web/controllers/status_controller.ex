defmodule ApiWeb.StatusController do
  use ApiWeb.Web, :controller

  def index(conn, _params) do
    feed_version = State.Metadata.feed_version()
    updated_timestamps = State.Metadata.updated_timestamps()

    data = %{
      feed_version: feed_version,
      timestamps: updated_timestamps
    }

    render(conn, "index.json-api", data: data)
  end
end
