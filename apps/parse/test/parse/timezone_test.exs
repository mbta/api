defmodule Parse.TimezoneTest do
  @moduledoc false
  use ExUnit.Case
  import Parse.Timezone

  doctest Parse.Timezone

  @two_hours 2 * 60 * 60

  describe "unix_to_local/2" do
    test "when springing forward, returns a time with the same Unix epoch" do
      # Sunday, March 11, 2018 1:00:00 AM GMT-05:00
      start = 1_520_748_000

      for time <- start..(start + @two_hours), rem(time, 300) == 0 do
        actual = unix_to_local(time)
        assert DateTime.to_unix(actual) == time
      end
    end

    test "when falling back, returns a time with the same Unix epoch" do
      # Sunday, November 4, 2018 1:00:00 AM GMT-04:00
      start = 1_541_307_600

      for time <- start..(start + @two_hours), rem(time, 300) == 0 do
        actual = unix_to_local(time)
        assert DateTime.to_unix(actual) == time
      end
    end
  end
end
