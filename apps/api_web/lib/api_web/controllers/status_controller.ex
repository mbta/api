defmodule ApiWeb.StatusController do
  use ApiWeb.Web, :controller

  def index(conn, _params) do
    {feed_version, feed_start_date, feed_end_date} = State.Metadata.feed_metadata()
    updated_timestamps = State.Metadata.updated_timestamps()

    data = %{
      feed: %{
        version: feed_version,
        start_date: feed_start_date,
        end_date: feed_end_date
      },
      timestamps: updated_timestamps
    }

    render(conn, "index.json-api", data: data)
  end
end
