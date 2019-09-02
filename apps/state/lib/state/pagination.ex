defmodule State.Pagination do
  @moduledoc """
  Utility module to paginate result-set items.
  """
  alias State.Pagination.Offsets

  @typep page_count :: pos_integer
  @type page_size :: non_neg_integer
  @type offset :: non_neg_integer
  @type pagination_option ::
          {:limit, page_size}
          | {:offset, offset}

  @doc """
  Paginates a result-set according to a list of options.

    * `results` - the list of results
    * `opts` - the Enum of options:
      * `:limit` - the number of results to be returned
      * `:offset` - the offset of results to beging selection from

  When `:limit` is provided, the function gives a tuple of the paginated list
  and a struct of pagination offset values for the next, previous, first and
  last pages.

  ## Examples
      iex(1)> items = [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5}]
      iex(2)> State.Pagination.paginate(items, limit: 2, offset: 2)
      {[%{id: 3}, %{id: 4}], %State.Pagination.Offsets{
        prev: 0,
        next: 4,
        first: 0,
        last: 4
      }}
  """
  @spec paginate([map]) :: [map] | {[map], Offsets.t()}
  @spec paginate([map], [pagination_option] | map) :: [map] | {[map], Offsets.t()}
  def paginate(results, opts \\ %{}) when is_list(results) do
    opts = Map.new(opts)

    case opts do
      %{limit: limit} when is_integer(limit) and limit > 0 ->
        offset = Map.get(opts, :offset, 0)

        page_count = page_count(results, limit)
        item_count = Enum.count(results)
        paged_results = Enum.slice(results, offset, limit)

        page_meta = %Offsets{
          prev: previous_page_offset(page_count, limit, offset),
          next: next_page_offset(page_count, limit, offset, item_count),
          first: 0,
          last: last_page_offset(page_count, limit)
        }

        {paged_results, page_meta}

      _ ->
        results
    end
  end

  @spec previous_page_offset(page_count, page_size, offset) :: offset | nil
  defp previous_page_offset(_pages, page_size, offset) do
    # Account for when offset isn't perfectly divisible by the page size
    page_offset_delta = Integer.mod(offset, page_size)
    current_page = Integer.floor_div(offset, page_size)

    cond do
      current_page > 0 and page_offset_delta == 0 ->
        (current_page - 1) * page_size

      page_offset_delta != 0 ->
        new_offset = (current_page - 1) * page_size + page_offset_delta
        safe_previous_offset(new_offset)

      true ->
        nil
    end
  end

  # Make sure previous offset is 0 at the lowest
  defp safe_previous_offset(offset) when offset < 0, do: 0
  defp safe_previous_offset(offset), do: offset

  @spec next_page_offset(page_count, page_size, offset, integer) :: offset | nil
  defp next_page_offset(pages, page_size, offset, item_count) do
    # Account for when offset isn't perfectly divisible by the page size
    page_offset_delta = Integer.mod(offset, page_size)
    current_page = Integer.floor_div(offset, page_size)

    cond do
      current_page < pages - 1 and page_offset_delta == 0 ->
        (current_page + 1) * page_size

      page_offset_delta != 0 ->
        new_offset = (current_page + 1) * page_size + page_offset_delta
        safe_next_offset(new_offset, item_count)

      true ->
        nil
    end
  end

  # Make sure offset doesn't go past the list size
  defp safe_next_offset(offset, item_count) when offset >= item_count, do: nil
  defp safe_next_offset(offset, _item_count), do: offset

  @spec last_page_offset(page_count, page_size) :: offset
  defp last_page_offset(pages, page_size) do
    (pages - 1) * page_size
  end

  @spec page_count([any], page_size) :: page_count
  defp page_count([], _), do: 1

  defp page_count(list, page_size) do
    list
    |> Stream.chunk_every(page_size)
    |> Enum.count()
  end
end
