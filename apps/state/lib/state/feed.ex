defmodule State.Feed do
  @moduledoc false
  use Events.Server

  alias Model.Feed
  alias Parse.FeedInfo

  @table __MODULE__

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get do
    [{:feed, feed}] = :ets.lookup(@table, :feed)
    feed
  end

  def new_state(%Feed{} = feed) do
    GenServer.call(__MODULE__, {:new_state, feed})
  end

  @doc """
  Gets the current feed version.
  """
  @spec current_version() :: String.t()
  def current_version do
    {:ok, %Feed{version: version}} = get()
    version
  end

  @impl Events.Server
  def handle_event({:fetch, "feed_info.txt"}, blob, _, state) do
    feed =
      case FeedInfo.parse(blob) do
        [feed | _] -> {:ok, feed}
        _ -> {:error, :failed}
      end

    update_feed(feed)
    {:noreply, state}
  end

  @impl GenServer
  def init(_) do
    @table = :ets.new(@table, [:named_table, :set, {:read_concurrency, true}])
    update_feed({:error, :not_loaded})
    Events.subscribe({:fetch, "feed_info.txt"}, nil)
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:new_state, feed}, _from, state) do
    update_feed({:ok, feed})
    {:reply, :ok, state}
  end

  defp update_feed(result) do
    :ets.insert(@table, {:feed, result})

    with {:ok, feed} <- result do
      State.Metadata.feed_updated(feed.version)
    end

    :ok
  end
end
