defmodule ApiWeb.ControllerHelpers do
  @moduledoc """
  Simple helpers for multiple controllers.
  """
  alias ApiWeb.LegacyStops

  import Plug.Conn

  @doc "Grab the ID from a struct/map"
  @spec id(%{id: any}) :: any
  def id(%{id: value}), do: value

  @doc """
  Returns the current service date for the connection. If one isn't present, we look it up and store it.
  """
  def conn_service_date(conn) do
    case conn.private do
      %{api_web_service_date: date} ->
        {conn, date}

      _ ->
        date = Parse.Time.service_date()
        conn = put_private(conn, :api_web_service_date, date)
        {conn, date}
    end
  end

  @doc """
  Given a map containing a set of filters, one of which expresses a list of stop IDs, expands the
  list using `LegacyStops` with the given API version.
  """
  @spec expand_stops_filter(map, any, String.t()) :: map
  def expand_stops_filter(filters, stops_key, api_version) do
    case Map.has_key?(filters, stops_key) do
      true -> Map.update!(filters, stops_key, &LegacyStops.expand(&1, api_version))
      false -> filters
    end
  end
end
