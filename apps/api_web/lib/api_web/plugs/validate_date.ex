defmodule ApiWeb.Plugs.ValidateDate do
  @moduledoc """
  A plug to make check that a date used as a query parameter is valid for the
  current rating.
  """

  @behaviour Plug

  alias JaSerializer.ErrorSerializer
  alias Plug.Conn
  alias State.Feed

  def init([]), do: []

  def call(%Conn{query_params: query_params} = conn, []) do
    query_params
    |> ApiWeb.Params.filter_params(["date"])
    |> Map.get("date")
    |> validate_date(conn)
  end

  defp validate_date(nil, conn), do: conn

  defp validate_date(date, conn) do
    if valid?(date) do
      conn
    else
      render_error(conn, error())
    end
  end

  defp valid?(date_str) do
    with {:ok, date} <- Date.from_iso8601(date_str),
         {:ok, feed} <- Feed.get() do
      Date.compare(date, feed.start_date) != :lt and Date.compare(date, feed.end_date) != :gt
    else
      _ -> false
    end
  end

  defp error do
    %{
      code: :no_service,
      description: "The current rating does not describe service on that date.",
      source: %{
        parameter: "date"
      },
      meta: meta(Feed.get())
    }
  end

  defp render_error(conn, params) do
    body =
      params
      |> ErrorSerializer.format(conn)
      |> Jason.encode!()

    conn
    |> Conn.send_resp(:bad_request, body)
    |> Conn.halt()
  end

  defp meta({:ok, feed}) do
    %{
      start_date: feed.start_date,
      end_date: feed.end_date,
      version: feed.version
    }
  end

  defp meta(_) do
    %{}
  end
end
