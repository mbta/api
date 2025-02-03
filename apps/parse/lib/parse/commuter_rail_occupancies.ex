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

  defp parse_record(
         %{
           "MedianDensity" => density,
           "MedianDensityFlag" => flag,
           "cTrainNo" => train
         } = record
       ) do
    with {:ok, flag} <- density_flag(flag),
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

  defp parse_record(
         %{
           "MedianDensity" => density,
           "MedianDensityFlag" => flag,
           "Trip Name" => train
         } = record
       ) do
    with {:ok, flag} <- density_flag(flag),
         {:ok, percentage} <- percentage(density),
         {:ok, name} <- trip_name(train) do
      model = %Model.CommuterRailOccupancy{
        percentage: percentage,
        status: flag,
        trip_name: name
      }

      Logger.error("OK we parsed #{inspect(model)}")

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

  defp parse_record(record) do
    Logger.warning("#{__MODULE__} parse_error error=missing_fields #{inspect(record)}")
    []
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
