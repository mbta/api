defmodule ApiWeb.EventStream.DiffTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties
  import ApiWeb.EventStream.Diff

  defp item(id, opts \\ []) do
    type = opts[:type] || "item"
    attributes = Map.new(Keyword.delete(opts, :type))

    %{
      "type" => type,
      "id" => id,
      "attributes" => attributes
    }
  end

  describe "diff/2" do
    test "returns empty lists if there are no changes" do
      item = item("1")

      assert diff([item], [item]) == %{
               add: [],
               update: [],
               remove: []
             }
    end

    test "can add items" do
      item = item("1")
      same = item("same")

      assert diff([same], [same, item]) == %{
               add: [item],
               update: [],
               remove: []
             }
    end

    test "can remove items" do
      item = item("1")
      same = item("2")

      assert diff([item, same], [same]) == %{
               add: [],
               update: [],
               remove: [%{"id" => "1", "type" => "item"}]
             }
    end

    test "can change items" do
      old = item("1")
      new = item("1", value: "new")

      assert diff([old], [new]) == %{
               add: [],
               update: [new],
               remove: []
             }
    end

    test "items with the same ID but different types are distinct" do
      a = item("1", type: "a")
      b = item("1", type: "b")
      same = item("2")

      assert diff([a, same], [b, same]) == %{
               add: [b],
               update: [],
               remove: [%{"id" => "1", "type" => "a"}]
             }
    end

    test "can add/update/remove in the same diff" do
      one = item("1")
      two_old = item("2")
      two_new = item("2", value: "new")
      three = item("3")
      four = item("4")

      assert diff([one, two_old, three], [two_new, three, four]) == %{
               add: [four],
               update: [two_new],
               remove: [%{"id" => "1", "type" => "item"}]
             }
    end

    test "if it's shorter, uses a full reset" do
      a = item("a")
      b = item("b")
      c = item("c")

      assert diff([a, b, c], [b]) == %{
               reset: [[b]]
             }
    end

    test "a diff from or to an empty list is a reset" do
      a = item("a")

      assert diff([], [a]) == %{
               reset: [[a]]
             }

      assert diff([a], []) == %{
               reset: [[]]
             }
    end

    test "items are added in order and removed in reverse order" do
      main_items = for id <- ~w(a b c d), do: item(id)
      added_items = for id <- ~w(add1 add2), do: item(id)
      full_items = added_items ++ main_items
      assert diff(main_items, full_items).add == added_items

      assert diff(full_items, main_items).remove ==
               added_items |> Enum.reverse() |> Enum.map(&Map.delete(&1, "attributes"))
    end
  end
end
