defmodule Parse.CommuterRailOccupancies do
  @moduledoc """
  Parser for the Commuter Rail Occupancy data from Keolis
  """

  require Logger

  @behaviour Parse

  @impl Parse
  def parse(binary) do
    case Jason.decode(binary) do
      {:ok, %{"data" => data}} when is_list(data) ->
        Enum.flat_map(data, &parse_record/1)

      {:ok, data} when is_list(data) ->
        Enum.flat_map(data, &parse_record/1)

      e ->
        Logger.warning("#{__MODULE__} decode_error e=#{inspect(e)}")
        []
    end
  end

  defp parse_density_fields(%{
         "MedianDensity" => density,
         "MedianDensityFlag" => flag,
         "cTrainNo" => train
       }),
       do: {:ok, {density, flag, train}}

  # new format keolis started providing when they switched this data over to S3
  defp parse_density_fields(%{
         "Median Density" => density,
         "Median Density Flag" => flag,
         "Trip Name" => train
       }),
       do: {:ok, {density, flag, train}}

  defp parse_density_fields(record) do
    Logger.warning("#{__MODULE__} parse_error error=missing_fields #{inspect(record)}")
    {:error, :missing_fields}
  end

  defp parse_record(record) do
    with {:ok, {density, flag, train}} <- parse_density_fields(record),
         {:ok, flag} <- density_flag(flag),
         {:ok, percentage} <- percentage(density),
         {:ok, name} <- trip_name(train) do
      [
        %Model.CommuterRailOccupancy{
          percentage: percentage,
          status: flag,
          trip_name: name
        }
      ]
    else
      error ->
        Logger.warning("#{__MODULE__} parse_error error=#{inspect(error)} #{inspect(record)}")
        []
    end
  end

  defp density_flag(0), do: {:ok, :many_seats_available}
  defp density_flag(1), do: {:ok, :few_seats_available}
  defp density_flag(2), do: {:ok, :full}
  defp density_flag(_), do: {:error, :unknown_density_flag}

  defp percentage(density) when is_float(density) do
    {:ok, round(density * 100)}
  end

  defp percentage(_), do: {:error, :bad_density}

  defp trip_name(train_number) when is_binary(train_number) do
    {:ok, String.trim_trailing(train_number)}
  end

  defp trip_name(_), do: {:error, :bad_trip_name}
end
