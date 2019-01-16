defmodule State.MetadataTest do
  use ExUnit.Case, async: false
  alias State.Metadata

  @datetime "2017-01-01T00:00:01.123456Z"

  def datetime do
    {:ok, datetime, _} = DateTime.from_iso8601(@datetime)
    datetime
  end

  defmodule FakeServer do
    def last_updated, do: State.MetadataTest.datetime()
  end

  setup do
    on_exit(fn -> :ets.delete_all_objects(Metadata.table_name()) end)
    :ok
  end

  test "init" do
    assert {:ok, _} = Metadata.init([])
  end

  describe "last_updated/1" do
    test "returns a timestamp even if we didn't get one from the server" do
      assert %DateTime{} = Metadata.last_updated(FakeServer)
    end

    test "fetches the cached timestamp" do
      expected = DateTime.utc_now()
      cache(FakeServer, expected)
      assert expected == Metadata.last_updated(FakeServer)
    end
  end

  describe "last_modified_header/1" do
    test "renders the last modified header" do
      assert <<_::binary-29>> = Metadata.last_modified_header(FakeServer)

      Metadata.state_updated(FakeServer, datetime())

      expected = "Sun, 01 Jan 2017 00:00:01 GMT"
      actual = Metadata.last_modified_header(FakeServer)
      assert expected == actual
    end
  end

  describe "state_updated/2" do
    test "caches the timestamp in ets" do
      Metadata.state_updated(FakeServer, datetime())
      expected = %{datetime() | microsecond: {0, 0}}
      assert cached?(FakeServer, expected)
    end

    test "overwrites any previous stored value" do
      Metadata.state_updated(FakeServer, datetime())
      now = DateTime.utc_now()
      Metadata.state_updated(FakeServer, now)
      expected = %{now | microsecond: {0, 0}}
      assert cached?(FakeServer, expected)
    end
  end

  describe "feed_updated/1" do
    test "caches the feed version" do
      version = "TEST_VERSION"
      Metadata.feed_updated(version)
      assert cached?(State.Feed, version)
    end

    test "overwrites a previously stored valued" do
      cache(State.Feed, "OLD_VERSION")
      expected = "UPDATED_VERSION"
      Metadata.feed_updated(expected)
      assert cached?(State.Feed, expected)
    end
  end

  describe "feed_version/0" do
    test "returns the cached feed version" do
      expected = "TEST_VERSION"
      cache(State.Feed, expected)
      assert Metadata.feed_version() == expected
    end

    test "fetches and caches feed version on cache miss" do
      :ets.delete(Metadata.table_name(), State.Feed)
      expected = "UPDATED_VERSION"
      State.Feed.new_state(%Model.Feed{version: expected})
      assert Metadata.feed_version() == expected
    end
  end

  test "updated_timestamps/0" do
    results = Metadata.updated_timestamps()
    assert Map.has_key?(results, :alert)
    assert Map.has_key?(results, :facility)
    assert Map.has_key?(results, :prediction)
    assert Map.has_key?(results, :route)
    assert Map.has_key?(results, :schedule)
    assert Map.has_key?(results, :service)
    assert Map.has_key?(results, :shape)
    assert Map.has_key?(results, :stop)
    assert Map.has_key?(results, :trip)
    assert Map.has_key?(results, :vehicle)
  end

  @doc """
  Caches a value.
  """
  def cache(key, value) do
    :ets.insert(Metadata.table_name(), {key, value})
  end

  @doc """
  Checks the State.Metatable for a cached value.
  """
  def cached?(key, value) do
    case :ets.lookup(Metadata.table_name(), key) do
      [{^key, ^value}] -> true
      _ -> false
    end
  end
end
