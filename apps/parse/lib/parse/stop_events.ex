defmodule Parse.StopEvents do
  @moduledoc """
  Parser for the Stop Events data from S3 (NDJSON format)
  """

  require Logger

  @behaviour Parse

  @impl Parse
  def parse(binary) do
    binary
    |> String.split("\n", trim: true)
    |> Enum.flat_map(&parse_line/1)
  end

  defp parse_line(line) do
    case Jason.decode(line) do
      {:ok, record} ->
        parse_record(record)

      e ->
        Logger.warning("#{__MODULE__} decode_error e=#{inspect(e)}")
        []
    end
  end

  defp parse_record(%{
         "start_date" => start_date,
         "trip_id" => trip_id,
         "vehicle_id" => vehicle_id,
         "direction_id" => direction_id,
         "route_id" => route_id,
         "start_time" => start_time,
         "revenue" => revenue,
         "stop_events" => stop_events
       })
       when is_list(stop_events) do
    with {:ok, date} <- parse_date(start_date),
         {:ok, revenue_atom} <- parse_revenue(revenue) do
      Enum.flat_map(stop_events, fn stop_event ->
        parse_stop_event(stop_event, %{
          start_date: date,
          trip_id: trip_id,
          vehicle_id: vehicle_id,
          direction_id: direction_id,
          route_id: route_id,
          start_time: start_time,
          revenue: revenue_atom
        })
      end)
    else
      error ->
        Logger.warning("#{__MODULE__} parse_error error=#{inspect(error)} trip_id=#{trip_id}")
        []
    end
  end

  defp parse_record(record) do
    Logger.warning("#{__MODULE__} parse_error error=missing_fields #{inspect(record)}")
    []
  end

  defp parse_stop_event(
         %{
           "stop_id" => stop_id,
           "current_stop_sequence" => current_stop_sequence,
           "arrived" => arrived,
           "departed" => departed
         },
         trip_data
       ) do
    [
      %Model.StopEvent{
        id: build_composite_key(trip_data, current_stop_sequence),
        vehicle_id: trip_data.vehicle_id,
        start_date: trip_data.start_date,
        trip_id: trip_data.trip_id,
        direction_id: trip_data.direction_id,
        route_id: trip_data.route_id,
        start_time: trip_data.start_time,
        revenue: trip_data.revenue,
        stop_id: stop_id,
        current_stop_sequence: current_stop_sequence,
        arrived: arrived,
        departed: departed
      }
    ]
  end

  defp parse_stop_event(stop_event, _trip_data) do
    Logger.warning("#{__MODULE__} parse_error error=missing_fields #{inspect(stop_event)}")
    []
  end

  defp build_composite_key(trip_data, current_stop_sequence) do
    "#{trip_data.trip_id}-#{trip_data.route_id}-#{trip_data.vehicle_id}-#{current_stop_sequence}"
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
end
