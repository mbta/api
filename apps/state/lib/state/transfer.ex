defmodule State.Transfer do
  @moduledoc """
  Maintains the current state of transfers.
  """

  use State.Server,
    indices: [:from_trip_id],
    fetched_filename: "transfers.txt",
    parser: Parse.Transfers,
    recordable: Model.Transfer

  @type filter_opts :: %{
          optional(:trips) => [Model.Trip.id()],
        }

  @type transfer_search :: (-> [Model.Transfer.t()])

  @doc """
  Applies a filtered search on Transfers based on a map of filter values.

  The allowed filterable keys are:
    :trips
  """
  @spec filter_by(filter_opts) :: [Model.Transfer.t()]
  def filter_by(filters) when is_map(filters) do
    filters
    |> build_filtered_searches()
    |> do_searches()
  end

  # Generate the functions needed to search concurrently
  @spec build_filtered_searches(filter_opts, [transfer_search]) :: [transfer_search]
  defp build_filtered_searches(filters, searches \\ [])

  defp build_filtered_searches(%{from_trip_ids: trip_ids} = filters, searches) do
    search_operation = fn -> by_from_trip_ids(trip_ids) end

    filters
    |> Map.drop([:from_trip_ids])
    |> build_filtered_searches([search_operation | searches])
  end

  defp build_filtered_searches(_, searches), do: searches

  @spec do_searches([transfer_search]) :: [Model.Transfer.t()]
  defp do_searches(search_operations) do
    search_operations
    |> Stream.map(fn search_operation ->
      case search_operation.() do
        results when is_list(results) ->
          results

        _ ->
          []
      end
    end)
    |> Enum.reduce(:no_results, fn
      results, :no_results -> MapSet.new(results)
      results, acc -> results |> MapSet.new() |> MapSet.intersection(acc)
    end)
    |> Enum.to_list()
  end
end
