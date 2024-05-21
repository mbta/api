defmodule ApiWeb.EventStream.Diff do
  @moduledoc """
  Diff two lists of JSON-API objects, returning a map of added/updated/removed elements.
  """

  @spec diff([map], [map]) :: %{add: [map], update: [map], remove: [map]} | %{reset: [[map]]}
  def diff([_ | _] = map_list_1, map_list_2) do
    list_1_map = Map.new(map_list_1, &by_key/1)
    list_2_map = Map.new(map_list_2, &by_key/1)
    added_map = Map.drop(list_2_map, Map.keys(list_1_map))
    removed_map = Map.drop(list_1_map, Map.keys(list_2_map))

    updated_map =
      for {key, value} <- list_2_map,
          {:ok, old_value} <- [Map.fetch(list_1_map, key)],
          value != old_value,
          into: %{} do
        {key, value}
      end

    update_size = map_size(added_map) + map_size(removed_map) + map_size(updated_map)

    if update_size <= map_size(list_2_map) do
      add = Enum.filter(map_list_2, &item_in_map(added_map, &1))
      update = Map.values(updated_map)

      remove =
        for item <- map_list_1,
            item_in_map(removed_map, item) do
          Map.take(item, ~w(id type))
        end
        |> Enum.reverse()

      %{
        add: add,
        update: update,
        remove: remove
      }
    else
      %{reset: [map_list_2]}
    end
  end

  def diff(_, map_list_2) do
    # don't need to bother with a diff if one of the lists is empty
    %{reset: [map_list_2]}
  end

  defp by_key(%{"type" => type, "id" => id} = item), do: {{type, id}, item}

  defp item_in_map(map, %{"type" => type, "id" => id}) do
    Map.has_key?(map, {type, id})
  end
end
