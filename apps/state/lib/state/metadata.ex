defmodule State.Metadata do
  @moduledoc """
  Holds metadata for State data.

  Currently, the only metadata being stored is when a service last received
  new data as well as the current feed version.
  """

  use GenServer

  @table_name :state_metadata

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, nil, name: opts[:name] || __MODULE__)
  end

  @impl GenServer
  def init(_) do
    table_opts = [:set, :named_table, :public, read_concurrency: true, write_concurrency: true]

    table_name = @table_name

    ^table_name =
      case :ets.info(@table_name) do
        :undefined -> :ets.new(@table_name, table_opts)
        _ -> table_name
      end

    {:ok, nil}
  end

  @doc false
  def table_name, do: @table_name

  @doc """
  Marks that a state's data was refreshed with new data.
  """
  def state_updated(mod, timestamp) do
    timestamp = %{timestamp | microsecond: {0, 0}}

    inserts = [
      {mod, timestamp},
      {{mod, :header}, rfc1123_format(timestamp)}
    ]

    :ets.insert(table_name(), inserts)
  rescue
    _ -> :error
  end

  @doc """
  Sets latest version, start_date and end_date of the Feed.
  """
  def feed_updated({version, start_date, end_date}) do
    :ets.insert(table_name(), {State.Feed, {version, start_date, end_date}})
  rescue
    _ -> :error
  end

  @doc """
  Gets the timestamp for when the state's data was last updated.
  """
  @spec last_updated(atom) :: DateTime.t() | nil
  def last_updated(mod) when is_atom(mod) do
    case :ets.lookup(table_name(), mod) do
      [{^mod, timestamp}] -> timestamp
      _ -> DateTime.utc_now()
    end
  end

  @doc """
  Gets the last-modified header value for the given state.
  """
  @spec last_modified_header(atom) :: String.t()
  def last_modified_header(mod) when is_atom(mod) do
    case :ets.lookup(table_name(), {mod, :header}) do
      [{_, header}] -> header
      _ -> rfc1123_format(DateTime.utc_now())
    end
  end

  @doc """
  Gets a tuple of the current feed version, start_date, and end_date.
  """
  @spec feed_metadata() :: {String.t(), Date.t(), Date.t()}
  def feed_metadata do
    case :ets.lookup(table_name(), State.Feed) do
      [{State.Feed, {version, start_date, end_date}}] ->
        {version, start_date, end_date}

      _ ->
        metadata = State.Feed.feed_metadata()
        feed_updated(metadata)
        metadata
    end
  end

  @doc """
  Fetches when each service was last updated.
  """
  def updated_timestamps do
    %{
      alert: last_updated(State.Alert),
      facility: last_updated(State.Facility),
      prediction: last_updated(State.Prediction),
      route: last_updated(State.Route),
      route_pattern: last_updated(State.RoutePattern),
      schedule: last_updated(State.Schedule),
      service: last_updated(State.Service),
      shape: last_updated(State.Shape),
      stop: last_updated(State.Stop.Cache),
      trip: last_updated(State.Trip),
      vehicle: last_updated(State.Vehicle)
    }
  end

  defp rfc1123_format(datetime) do
    {:ok, <<rendered::binary-26, "Z">>} = Timex.format(datetime, "{RFC1123z}")
    rendered <> "GMT"
  end
end
