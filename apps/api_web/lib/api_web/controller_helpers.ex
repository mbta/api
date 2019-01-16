defmodule ApiWeb.ControllerHelpers do
  @moduledoc """
  Simple helpers for multiple controllers.
  """
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
end
