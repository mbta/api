defmodule State.PaginationTest do
  use ExUnit.Case, async: true
  doctest State.Pagination

  alias State.Pagination
  alias State.Pagination.Offsets

  @items for i <- 1..10, do: %{id: i}

  describe "paginate/2" do
    test "only pages when :limit is set" do
      assert Pagination.paginate(@items) == @items
      assert Pagination.paginate(@items, offset: 3) == @items
    end

    test "pages and includes pagination metadata" do
      expected_meta = %Offsets{
        prev: 0,
        next: 4,
        first: 0,
        last: 8
      }

      expected_results = [%{id: 3}, %{id: 4}]
      {result_list, result_meta} = Pagination.paginate(@items, limit: 2, offset: 2)

      assert result_list == expected_results
      assert result_meta == expected_meta
    end

    test "excludes :previous from metadata when on first page" do
      expected_meta = %Offsets{
        prev: nil,
        next: 2,
        first: 0,
        last: 8
      }

      expected_results = [%{id: 1}, %{id: 2}]
      {result_list, result_meta} = Pagination.paginate(@items, limit: 2)

      assert result_list == expected_results
      assert result_meta == expected_meta
    end

    test "excludes :next from metadata when on last page" do
      expected_meta = %Offsets{
        prev: 6,
        next: nil,
        first: 0,
        last: 8
      }

      expected_results = [%{id: 9}, %{id: 10}]
      {result_list, result_meta} = Pagination.paginate(@items, limit: 2, offset: 8)

      assert result_list == expected_results
      assert result_meta == expected_meta
    end

    test "handles offsets that aren't even divisors of the limit" do
      expected_meta_lower = %Offsets{
        prev: 0,
        next: 5,
        first: 0,
        last: 9
      }

      expected_meta_middle = %Offsets{
        prev: 2,
        next: 8,
        first: 0,
        last: 9
      }

      expected_meta_upper = %Offsets{
        prev: 2,
        next: nil,
        first: 0,
        last: 8
      }

      expected_results_lower = [%{id: 3}, %{id: 4}, %{id: 5}]
      expected_results_middle = [%{id: 6}, %{id: 7}, %{id: 8}]
      expected_results_upper = [%{id: 7}, %{id: 8}, %{id: 9}, %{id: 10}]

      {result_list, result_meta} = Pagination.paginate(@items, limit: 3, offset: 2)
      assert result_list == expected_results_lower
      assert result_meta == expected_meta_lower

      {result_list, result_meta} = Pagination.paginate(@items, limit: 3, offset: 5)
      assert result_list == expected_results_middle
      assert result_meta == expected_meta_middle

      {result_list, result_meta} = Pagination.paginate(@items, limit: 4, offset: 6)
      assert result_list == expected_results_upper
      assert result_meta == expected_meta_upper
    end
  end
end
