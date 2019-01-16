defmodule ApiWeb.RateLimiter.ETS do
  @moduledoc """
  RateLimiter backend which uses an ETS table as the backend.
  """
  @behaviour ApiWeb.RateLimiter.Limiter
  use GenServer

  @tab :mbta_api_rate_limiter

  @impl ApiWeb.RateLimiter.Limiter
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl ApiWeb.RateLimiter.Limiter
  def rate_limited?(user_id, max_requests) do
    :ets.update_counter(@tab, user_id, {2, 1}, {user_id, 0}) > max_requests
  end

  @impl ApiWeb.RateLimiter.Limiter
  def clear do
    GenServer.call(__MODULE__, :force_clear)
  end

  @impl ApiWeb.RateLimiter.Limiter
  def list do
    :ets.select(@tab, [{{:"$1", :_}, [], [:"$1"]}])
  end

  @impl GenServer
  def init(opts) do
    clear_interval = Keyword.fetch!(opts, :clear_interval)
    table_opts = [:set, :named_table, :public, read_concurrency: true, write_concurrency: true]

    _ =
      if :ets.info(@tab) == :undefined do
        _ = :ets.new(@tab, table_opts)
      end

    state = schedule_clear(%{clear_interval: clear_interval, ref: nil})

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:force_clear, _from, state) do
    clear_tab()
    state = schedule_clear(state)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info(:clear, state) do
    clear_tab()
    state = schedule_clear(state)
    {:noreply, state}
  end

  defp schedule_clear(state) do
    _ = if state.ref, do: Process.cancel_timer(state.ref)

    ref = Process.send_after(self(), :clear, state.clear_interval)
    %{state | ref: ref}
  end

  defp clear_tab do
    :ets.delete_all_objects(@tab)
  end
end
