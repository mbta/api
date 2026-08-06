defmodule Parse.StopEvents do
  @moduledoc """
  Parses line-delimited [gzipped] JSON into a list of `%Model.StopEvent{}` structs. The expected JSON comes from LAMP's `flashback` application.

  Records not parsed are logged and filtered out.
  """

  require Logger

  @behaviour Parse

  @impl Parse
  def parse(binary) when is_binary(binary) do
    parse(binary, [])
  end

  @spec parse(binary(), keyword()) :: [Model.StopEvent.t()] | {:partial, [Model.StopEvent.t()]}
  def parse(body, opts) when is_binary(body) and is_list(opts) do
    newer_than = Keyword.get(opts, :newer_than)

    events =
      body
      |> decompress()
      |> String.split("\n", trim: true)
      |> Enum.map(&parse_line(&1, newer_than))
      |> Enum.reject(&is_nil/1)

    # When filtering by timestamp, always return {:partial, events} tuple
    # to distinguish filtered updates from full state replacements
    if newer_than do
      {:partial, events}
    else
      events
    end
  end

  defp decompress(body) do
    :zlib.gunzip(body)
  rescue
    _ -> body
  end

  defp parse_line(line, newer_than) do
    case Jason.decode(line) do
      {:ok, record} ->
        if should_include_record?(record, newer_than) do
          parse_record(record)
        else
          nil
        end

      e ->
        Logger.error("#{__MODULE__} decode_error error=#{inspect(e)}")
        nil
    end
  end

  defp should_include_record?(_record, nil), do: true

  defp should_include_record?(%{"timestamp" => timestamp}, newer_than)
       when is_integer(timestamp) and is_integer(newer_than) do
    timestamp > newer_than
  end

  # Records without a timestamp field are excluded when filtering is active.
  # This treats records without timestamps as stale/invalid when doing incremental updates.
  defp should_include_record?(_record, _newer_than), do: false

  defp parse_record(
         %{
           "id" => id,
           "vehicle_id" => vehicle_id,
           "start_date" => start_date,
           "trip_id" => trip_id,
           "direction_id" => direction_id,
           "route_id" => route_id,
           "stop_id" => stop_id,
           "stop_sequence" => stop_sequence,
           "revenue" => revenue
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
        revenue: revenue_atom,
        stop_id: stop_id,
        stop_sequence: stop_sequence,
        arrived: arrived,
        departed: departed,
        timestamp: Map.get(record, "timestamp")
      }
    else
      {:error, reason} ->
        Logger.error("#{__MODULE__} parse_error error=#{reason} record=#{inspect(record)}")
        nil
    end
  end

  defp parse_record(record) do
    Logger.error("#{__MODULE__} parse_error error=missing_fields #{inspect(record)}")
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
    _e ->
      {:error, :invalid_unix_timestamp}
  end

  defp parse_timestamp(_invalid) do
    {:error, :invalid_timestamp_type}
  end
end
