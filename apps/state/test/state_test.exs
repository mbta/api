defmodule StateTest do
  use ExUnit.Case
  use ExUnitProperties
  doctest State, only: [all: 2]

  @items for i <- 1..10, do: %{id: i}

  test "config/1 returns configuration" do
    assert Keyword.keyword?(State.config(:shape))
  end

  test "config/1 raises when key is missing" do
    assert_raise ArgumentError, fn -> State.config(:not_exists) end
  end

  test "config/2 returns configuration" do
    assert is_map(State.config(:shape, :overrides))
  end

  test "config/2 raises when key is missing" do
    assert_raise KeyError, fn -> State.config(:shape, :not_exists) end
  end

  describe "order_by/2" do
    test "only sorts when :order_by is set" do
      shuffled_items = Enum.shuffle(@items)
      assert State.order_by(shuffled_items) == shuffled_items
    end

    test "sorts by an ascending key" do
      shuffled_items = Enum.shuffle(@items)
      assert State.order_by(shuffled_items, order_by: {:id, :asc}) == @items
    end

    test "sorts by an descending key" do
      shuffled_items = Enum.shuffle(@items)
      assert State.order_by(shuffled_items, order_by: {:id, :desc}) == Enum.reverse(@items)
    end

    test "errors with invalid order_by key" do
      shuffled_items = Enum.shuffle(@items)

      assert State.order_by(shuffled_items, order_by: {:invalid, :desc}) ==
               {:error, :invalid_order_by}
    end

    test "sorts by distance when lat/lng are given" do
      items = [
        one = %{latitude: 1.0, longitude: 2.0},
        two = %{latitude: 1.0, longitude: 1.0},
        three = %{latitude: 1.0, longitude: 3.0}
      ]

      assert State.order_by(
               items,
               latitude: "0.0",
               longitude: "0.0",
               order_by: [distance: :asc]
             ) == [two, one, three]

      assert State.order_by(
               items,
               latitude: "0.0",
               longitude: "0.0",
               order_by: [distance: :desc]
             ) == [three, one, two]
    end

    test "sorting by distance returns error when missing lat/lng" do
      items = [
        %{latitude: 1.0, longitude: 2.0},
        %{latitude: 1.0, longitude: 1.0}
      ]

      assert State.order_by(
               items,
               latitude: "0.0",
               order_by: [distance: :asc]
             ) == {:error, :invalid_order_by}

      assert State.order_by(
               items,
               longitude: "0.0",
               order_by: [distance: :asc]
             ) == {:error, :invalid_order_by}

      assert State.order_by(
               items,
               order_by: [distance: :asc]
             ) == {:error, :invalid_order_by}
    end

    test "sorts by time" do
      items = [
        %{arrival_time: nil, departure_time: nil},
        %{arrival_time: DateTime.from_unix!(1_000), departure_time: nil},
        %{arrival_time: nil, departure_time: DateTime.from_unix!(2_000)},
        %{arrival_time: DateTime.from_unix!(3_000), departure_time: DateTime.from_unix!(4_000)}
      ]

      shuffled_items = Enum.shuffle(items)
      assert State.order_by(shuffled_items, order_by: [time: :asc]) == items
      assert State.order_by(shuffled_items, order_by: [time: :desc]) == Enum.reverse(items)
    end

    test "sorting by time returns error when no arrival_time or departure_time" do
      items = [
        %{stop_id: "1", parent_station: "place-sstat"},
        %{stop_id: "2", parent_station: nil}
      ]

      assert State.order_by(items, order_by: [time: :asc]) == {:error, :invalid_order_by}
    end

    property "sorting by time always works properly" do
      check all(times <- list_of(integer())) do
        items = for time <- times, do: %{arrival_time: DateTime.from_unix!(time)}

        expected = Enum.sort_by(items, &DateTime.to_unix(&1.arrival_time))
        actual = State.order_by(items, order_by: [time: :asc])

        assert expected == actual
      end
    end

    test "can sort by multiple keys" do
      items = [
        one = %{a: 1, b: 1},
        two = %{a: 1, b: 2},
        three = %{a: 2, b: 2}
      ]

      assert State.order_by(items, order_by: [a: :asc, b: :desc]) == [two, one, three]
    end

    test "converts arrival_time to unix before sorting by it" do
      # The specific NaiveDateTime structs are used below to provide coverage
      # for scenarios as described here:
      # https://github.com/elixir-lang/elixir/issues/5181
      items = [
        %{id: 1, arrival_time: nil},
        %{id: 2, arrival_time: DateTime.from_naive!(~N[2016-08-31T20:00:00], "Etc/UTC")},
        %{id: 3, arrival_time: DateTime.from_naive!(~N[2016-09-01T01:00:00], "Etc/UTC")}
      ]

      shuffled_items = Enum.shuffle(items)
      assert State.order_by(shuffled_items, order_by: {:arrival_time, :asc}) == items

      assert State.order_by(shuffled_items, order_by: {:arrival_time, :desc}) ==
               Enum.reverse(items)
    end
  end
end
