defmodule Parse.Facility.Parking do
  @moduledoc """
  Parses the JSON from an IBM endpoint hooked up to some of the MBTA's parking garages.

  ## Format

  The file looks like:

      {
        "counts": [
          {
            "garageName": "MBTA Route 128",
            "freeSpace": "1020",
            "capacity": "2430",
            "displayStatus": "NULL",
            "dateTime": "05/21/18 16:19:59",
            "garageId": "0"
          },
          ...
        ]
      }

  - `garageName` is mapped to a facility ID with the `Facility.Parking` `garages` config
  - `dateTime` is in local time
  """
  @behaviour Parse

  alias Model.Facility.Property

  @impl Parse
  def parse(binary) do
    case Jason.decode(binary) do
      {:ok, %{"counts" => [_ | _] = counts}} ->
        Enum.flat_map(counts, &parse_count/1)

      _ ->
        []
    end
  end

  defp parse_count(%{"garageName" => garage_name, "dateTime" => date_time} = count) do
    with {:ok, facility_id} <- garage_name_to_facility_id(garage_name),
         {:ok, updated_at} <- parking_date_time(date_time) do
      base_property = %Property{
        facility_id: facility_id,
        updated_at: updated_at
      }

      capacity = count |> Map.get("capacity") |> to_integer()
      free_space = count |> Map.get("freeSpace") |> to_integer()
      status = count |> Map.get("displayStatus") |> display_status()

      for {name, value} <- [
            capacity: capacity,
            utilization: capacity - free_space,
            status: status
          ] do
        %{base_property | name: Atom.to_string(name), value: value}
      end
    else
      _ ->
        []
    end
  end

  for {garage_name, facility_id} <- Application.compile_env(:parse, Facility.Parking)[:garages] do
    defp garage_name_to_facility_id(unquote(garage_name)), do: {:ok, unquote(facility_id)}
  end

  defp garage_name_to_facility_id(_), do: :error

  defp parking_date_time(
         <<month::binary-2, ?/, day::binary-2, ?/, year2::binary-2, " ", hour::binary-2, ?:,
           minute::binary-2, ?:, second::binary-2>>
       ) do
    naive = %NaiveDateTime{
      year: 2000 + String.to_integer(year2),
      month: String.to_integer(month),
      day: String.to_integer(day),
      hour: String.to_integer(hour),
      minute: String.to_integer(minute),
      second: String.to_integer(second),
      microsecond: {0, 0}
    }

    {:ok, Timex.to_datetime(naive, "America/New_York")}
  end

  defp parking_date_time(_), do: :error

  defp to_integer(binary) when is_binary(binary), do: String.to_integer(binary)
  defp to_integer(integer) when is_integer(integer), do: integer

  defp display_status("NULL"), do: nil
  defp display_status(status) when is_binary(status), do: status
end
