defmodule State.FeedTest do
  use ExUnit.Case
  import State.Feed
  alias Model.Feed

  @blob """
  "feed_publisher_name","feed_publisher_url","feed_lang","feed_start_date","feed_end_date","feed_version"
  "MBTA","http://www.mbta.com","EN",20170228,20170623,"Spring 2017 version 2D, 3/2/17"
  """

  defp await_feed_status(status) do
    case get() do
      {^status, _} -> :ok
      _ -> await_feed_status(status)
    end
  end

  describe "new_state/1" do
    setup do
      Events.publish({:fetch, "feed_info.txt"}, "")
      await_feed_status(:error)
      :ok
    end

    test "listens for the feed_info file" do
      Events.publish({:fetch, "feed_info.txt"}, @blob)
      await_feed_status(:ok)
      assert {:ok, %Feed{name: "MBTA"}} = get()
      Events.publish({:fetch, "feed_info.txt"}, "")
      await_feed_status(:error)
      assert {:error, _} = get()
    end

    test "caches the feed Metadata" do
      version = "TEST_VERSION"
      start_date = ~D[2019-01-01]
      end_date = ~D[2019-01-02]
      State.Feed.new_state(%Feed{version: version, start_date: start_date, end_date: end_date})
      await_feed_status(:ok)
      assert State.Metadata.feed_metadata() == {version, start_date, end_date}
    end
  end

  test "feed_metadata/0" do
    Events.publish({:fetch, "feed_info.txt"}, @blob)
    await_feed_status(:ok)
    assert State.Feed.feed_metadata()
  end
end
