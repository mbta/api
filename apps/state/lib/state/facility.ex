defmodule State.Facility do
  @moduledoc """
  Manages the list of elevators/escalators.
  """
  alias Model.Facility
  alias Model.Stop

  use State.Server,
    fetched_filename: "facilities.txt",
    recordable: Model.Facility,
    indicies: [:id, :stop_id, :type],
    parser: Parse.Facility

  @type filter_opts :: %{
          optional(:stops) => [Stop.id()],
          optional(:types) => [String.t()]
        }

  @type facility_search :: (() -> [Facility.t()])

  # If you change this list, be sure to also update the gtfs-documentation
  @facility_types ~w(
    BIKE_STORAGE
    BRIDGE_PLATE
    ELECTRIC_CAR_CHARGERS
    ELEVATED_SUBPLATFORM
    ELEVATOR
    ESCALATOR
    FARE_MEDIA_ASSISTANCE_FACILITY
    FARE_MEDIA_ASSISTANT
    FARE_VENDING_MACHINE
    FARE_VENDING_RETAILER
    FULLY_ELEVATED_PLATFORM
    OTHER
    PARKING_AREA
    PICK_DROP
    PORTABLE_BOARDING_LIFT
    RAMP
    TAXI_STAND
    TICKET_WINDOW
  )

  def facility_types, do: @facility_types

  def by_id(id) do
    case super(id) do
      [] -> nil
      [facility] -> facility
    end
  end

  @doc """
  Applies a filtered search on Facilities based on a map of filter values.

  The allowed filterable keys are:
    :stops
    :types
  """
  @spec filter_by(filter_opts) :: [Facility.t()]
  def filter_by(filters) when is_map(filters) do
    filters
    |> build_filtered_searches()
    |> do_searches()
  end

  # Generate the functions needed to search concurrently
  @spec build_filtered_searches(filter_opts, [facility_search]) :: [facility_search]
  defp build_filtered_searches(filters, searches \\ [])

  defp build_filtered_searches(%{types: types} = filters, searches) do
    search_operation = fn -> by_types(types) end

    filters
    |> Map.drop([:types])
    |> build_filtered_searches([search_operation | searches])
  end

  defp build_filtered_searches(%{stops: stop_ids} = filters, searches) do
    search_operation = fn -> by_stop_ids(stop_ids) end

    filters
    |> Map.drop([:stops])
    |> build_filtered_searches([search_operation | searches])
  end

  defp build_filtered_searches(_, searches), do: searches

  @spec do_searches([facility_search]) :: [Facility.t()]
  defp do_searches([]), do: all()

  defp do_searches(search_operations) do
    search_results =
      Enum.map(search_operations, fn search_operation ->
        case search_operation.() do
          results when is_list(results) ->
            results

          _ ->
            []
        end
      end)

    search_results |> List.flatten() |> Enum.uniq()
  end
end
