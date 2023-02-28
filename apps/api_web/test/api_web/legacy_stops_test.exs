defmodule ApiWeb.LegacyStopsTest do
  use ExUnit.Case, async: true

  import ApiWeb.LegacyStops

  describe "expand/3" do
    test "inserts additional stop IDs into a list according to a mapping" do
      mappings = %{"2020-01-01" => %{"one" => {"five", []}, "three" => {nil, ~w(six seven)}}}
      stops = expand(~w(one two three four), "2019-01-01", mappings: mappings)
      assert stops == ~w(one five two three six seven four)
    end

    test "only applies mappings with versions ahead of the given version" do
      mappings = %{
        "2019-01-01" => %{"one" => {"two", []}},
        "2020-01-01" => %{"threepig" => {"four", []}}
      }

      assert expand(~w(one three), "2019-07-01", mappings: mappings) == ~w(one three four)
    end

    test "applies multiple mappings for the same stop ID" do
      mappings = %{
        "2019-01-01" => %{"one" => {"two", []}},
        "2020-01-01" => %{"one" => {"three", []}}
      }

      assert expand(~w(one), "2018-01-01", mappings: mappings) == ~w(one three two)
    end

    test "applies mappings in version order when the output of one is an input to another" do
      mappings = %{
        "2018-01-01" => %{"two" => {"four", []}},
        "2020-01-01" => %{"two" => {"three", []}},
        "2019-01-01" => %{"one" => {"two", []}}
      }

      assert expand(~w(one), "2018-07-01", mappings: mappings) == ~w(one two three)
    end

    test "has an option to only apply renames" do
      mappings = %{
        "2019-01-01" => %{"old" => {nil, ~w(old1)}},
        "2020-01-01" => %{"old" => {"new", []}, "old1" => {"new1", []}}
      }

      assert expand(~w(old), "2018-01-01", mappings: mappings) == ~w(old new old1 new1)
      assert expand(~w(old), "2018-01-01", mappings: mappings, only_renames: true) == ~w(old new)
    end

    test "accepts an empty input" do
      assert expand([], "2019-01-01", mappings: %{"2020-01-01" => %{}}) == []
    end

    test "makes no changes with no mappings" do
      assert expand(~w(test one two), "2000-01-01", mappings: %{}) == ~w(test one two)
    end

    test "makes no changes if none of the input IDs have mappings defined" do
      mappings = %{"2020-01-01" => %{"three" => {"four", []}}}

      assert expand(~w(test one two), "2019-01-01", mappings: mappings) == ~w(test one two)
    end

    test "makes no changes if no mapping versions are ahead of the given version" do
      mappings = %{
        "2019-01-01" => %{"test" => {"other", []}},
        "2020-01-01" => %{"two" => {"three", []}}
      }

      assert expand(~w(test one two), "2020-01-01", mappings: mappings) == ~w(test one two)
    end
  end
end
