defmodule Parse.TimeTest do
  use ExUnit.Case, async: true
  import Parse.Time

  describe "now/0" do
    test "returns the current time in America/New_York" do
      now_utc = DateTime.utc_now()
      now_local = now()
      assert now_local.time_zone == "America/New_York"
      assert_in_delta DateTime.to_unix(now_utc), DateTime.to_unix(now_local), 1
    end
  end

  describe "service_date/0" do
    test "returns the service date for the current time" do
      assert service_date() == service_date(Timex.now("America/New_York"))
    end
  end

  describe "service_date/1" do
    test "returns the service date" do
      expected = ~D[2016-01-01]

      for time_str <- [
            "2016-01-01T03:00:00-05:00",
            "2016-01-01T12:00:00-05:00",
            "2016-01-02T02:59:59-05:00"
          ] do
        date_time = Timex.parse!(time_str, "{ISO:Extended}")
        assert {time_str, service_date(date_time)} == {time_str, expected}
      end
    end

    test "function handles an ambiguous datetime" do
      expected = ~D[2017-11-04]

      res =
        ~N[2017-11-05T01:59:00]
        |> Timex.to_datetime("America/New_York")
        |> service_date()

      assert res == expected
    end

    test "function handles shifting into ambiguous datetime" do
      expected = ~D[2017-11-04]

      res =
        ~N[2017-11-04T04:59:00]
        |> Timex.to_datetime("America/New_York")
        |> service_date()

      assert res == expected
    end
  end
end
