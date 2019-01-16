defmodule Parse.FeedInfoTest do
  use ExUnit.Case, async: true
  import Parse.FeedInfo
  alias Model.Feed

  @blob """
  "feed_publisher_name","feed_publisher_url","feed_lang","feed_start_date","feed_end_date","feed_version"
  "MBTA","http://www.mbta.com","EN",20170228,20170623,"Spring 2017 version 2D, 3/2/17"
  """

  describe "parse/1" do
    test "parses a CSV into a list of %Feed{} structs" do
      assert parse(@blob) ==
               [
                 %Feed{
                   name: "MBTA",
                   start_date: ~D[2017-02-28],
                   end_date: ~D[2017-06-23],
                   version: "Spring 2017 version 2D, 3/2/17"
                 }
               ]
    end
  end
end
