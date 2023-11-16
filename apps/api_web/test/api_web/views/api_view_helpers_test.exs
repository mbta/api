defmodule ApiWeb.ApiViewHelpersTest do
  use ExUnit.Case
  alias ApiWeb.ApiViewHelpers
  import ApiViewHelpers

  @service_id "service"
  @trip_id "trip"
  @trip %Model.Trip{
    block_id: "block_id",
    id: @trip_id,
    route_id: "9",
    direction_id: 1,
    service_id: @service_id
  }
  @today Parse.Time.service_date()
  @service %Model.Service{
    id: @service_id,
    start_date: @today,
    end_date: @today,
    added_dates: [@today]
  }
  @api_key String.duplicate("v", 32)

  describe "trip/2" do
    test "with nil trip uses trip_id" do
      trip_id = 0

      assert trip(%{trip: nil, trip_id: trip_id}, %Plug.Conn{}) == trip_id
    end

    test "with trip uses trip" do
      trip = %Model.Trip{}

      assert trip(%{trip: trip}, %Plug.Conn{}) == trip
    end

    test "otherwise uses trip_id to lookup trip" do
      State.Trip.new_state([])
      conn = %Plug.Conn{assigns: %{split_include: MapSet.new(["trip"])}}

      assert trip(%{trip_id: @trip_id}, conn) == nil

      State.Service.new_state([@service])
      State.Trip.new_state(%{multi_route_trips: [], trips: [@trip]})

      assert trip(%{trip_id: @trip_id}, conn) == @trip
    end
  end

  test "url_safe_id/2 encodes a struct's `:id` to be URL safe" do
    id = "River Works / GE Employees Only"
    expected = "River%20Works%20%2F%20GE%20Employees%20Only"
    struct = %{id: id}

    assert URI.decode(expected) == id
    assert url_safe_id(struct, %{}) == expected
  end

  describe "interval_atom/1" do
    test "returns per-minute limit" do
      assert interval_atom(60_000) == :per_minute_limit
    end

    test "returns hourly limit" do
      assert interval_atom(3_600_000) == :hourly_limit
    end

    test "returns daily limit" do
      assert interval_atom(86_400_000) == :daily_limit
    end

    test "truncates to the second if doesn't match a simple case" do
      assert interval_atom(2_756) == :requests_per_seconds
    end
  end

  describe "interval_name/1" do
    test "returns per-minute limit" do
      assert interval_name(60_000) == "Per-Minute Limit"
    end

    test "returns hourly limit" do
      assert interval_name(3_600_000) == "Hourly Limit"
    end

    test "returns daily limit" do
      assert interval_name(86_400_000) == "Daily Limit"
    end

    test "truncates to the second if doesn't match a simple case" do
      assert interval_name(2_756) == "Requests Per 2.76 Seconds"
    end
  end

  test "limit/1 returns properly formatted rate limit per key" do
    key = %ApiAccounts.Key{key: @api_key}
    assert limit(key) == ApiWeb.config(:rate_limiter, :max_registered_per_interval)
  end

  test "limit_value/1 returns nil if daily_limit is not set" do
    key = %ApiAccounts.Key{key: @api_key, daily_limit: nil}
    assert limit_value(key) == nil
  end

  test "limit_value/1 returns formatted limit value if set" do
    key = %ApiAccounts.Key{key: @api_key, daily_limit: 10_000 * 60 * 24}
    assert limit_value(key) == limit(key)
  end
end
