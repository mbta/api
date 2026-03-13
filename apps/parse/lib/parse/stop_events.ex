defmodule Parse.StopEvents do
  @moduledoc """
  Parses line-delimited [gzipped] JSON into a list of `%Model.StopEvent{}` structs.
  """

  require Logger

  @behaviour Parse

  @impl Parse
  def parse(body) do
    body
    |> decompress()
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp decompress(body) do
    :zlib.gunzip(body)
  rescue
    _ -> body
  end

  defp parse_line(line) do
    case Jason.decode(line) do
      {:ok, record} ->
        parse_record(record)

      e ->
        Logger.warning("#{__MODULE__} decode_error e=#{inspect(e)}")
        nil
    end
  end

  defp parse_record(
         %{
           "start_date" => start_date,
           "id" => id,
           "trip_id" => trip_id,
           "vehicle_id" => vehicle_id,
           "direction_id" => direction_id,
           "route_id" => route_id,
           "start_time" => start_time,
           "revenue" => revenue,
           "stop_id" => stop_id,
           "stop_sequence" => stop_sequence
         } = record
       ) do
    with {:ok, date} <- parse_date(start_date),
         {:ok, revenue_atom} <- parse_revenue(revenue),
         {:ok, arrived} <- parse_timestamp(Map.get(record, "arrived")),
         {:ok, departed} <- parse_timestamp(Map.get(record, "departed")) do
      %Model.StopEvent{
        id: id,
        vehicle_id: vehicle_id,
        start_date: date,
        trip_id: trip_id,
        direction_id: direction_id,
        route_id: route_id,
        start_time: start_time,
        revenue: revenue_atom,
        stop_id: stop_id,
        stop_sequence: stop_sequence,
        arrived: arrived,
        departed: departed
      }
    else
      {:error, reason} ->
        Logger.warning("#{__MODULE__} parse_error error=#{reason} record=#{inspect(record)}")
        nil
    end
  end

  defp parse_record(record) do
    Logger.warning("#{__MODULE__} parse_error error=missing_fields #{inspect(record)}")
    nil
  end

  defp parse_date(<<year::binary-size(4), month::binary-size(2), day::binary-size(2)>>) do
    case Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day)) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :invalid_date}
    end
  end

  defp parse_date(_), do: {:error, :invalid_date}

  defp parse_revenue(true), do: {:ok, :REVENUE}
  defp parse_revenue(false), do: {:ok, :NON_REVENUE}
  defp parse_revenue(_), do: {:error, :invalid_revenue}

  defp parse_timestamp(nil), do: {:ok, nil}

  defp parse_timestamp(unix_timestamp) when is_integer(unix_timestamp) do
    {:ok, Parse.Timezone.unix_to_local(unix_timestamp)}
  rescue
    e ->
      {:error, "invalid_timestamp: #{inspect(e)}"}
  end

  defp parse_timestamp(_invalid) do
    {:error, :invalid_timestamp_type}
  end
end
