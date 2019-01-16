defmodule StateMediator.Mediator do
  @moduledoc """

  Mediator is responsible for periodically fetching a URL and passing it to
  another module for handling.

  """
  defstruct [
    :module,
    :url,
    {:fetch_opts, []},
    :sync_timeout,
    :interval,
    {:retries, 0}
  ]

  @opaque t :: %__MODULE__{
            module: module,
            url: String.t(),
            fetch_opts: Keyword.t(),
            sync_timeout: pos_integer,
            interval: pos_integer | nil,
            retries: non_neg_integer
          }

  # 5 minutes
  @max_retry_duration 60 * 5

  use GenServer
  require Logger

  @spec start_link(Keyword.t()) :: {:ok, pid}
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @spec stop(pid) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @spec init(Keyword.t()) :: {:ok, __MODULE__.t()} | no_return
  def init(options) do
    state_module = Keyword.fetch!(options, :state)

    url = Keyword.fetch!(options, :url)
    fetch_opts = Keyword.get(options, :opts, [])
    sync_timeout = options |> Keyword.get(:sync_timeout, 5000)
    interval = options |> Keyword.get(:interval)

    if url == "" do
      :ignore
    else
      send(self(), :initial)

      {:ok,
       %__MODULE__{
         module: state_module,
         url: url,
         fetch_opts: fetch_opts,
         sync_timeout: sync_timeout,
         interval: interval
       }}
    end
  end

  @spec handle_info(:initial | :timeout, t) :: {:noreply, t} | {:noreply, t, :hibernate}
  def handle_info(:initial, %{module: state_module} = state) do
    _ = Logger.debug(fn -> "#{__MODULE__} #{state_module} initial sync starting" end)
    require_body? = state_module.size == 0
    fetch(state, require_body: require_body?)
  end

  def handle_info(:timeout, %{module: state_module} = state) do
    _ = Logger.debug(fn -> "#{__MODULE__} #{state_module} timeout sync starting" end)
    fetch(state)
  end

  defp fetch(%{url: url, fetch_opts: fetch_opts} = state, opts \\ []) do
    data =
      debug_time("fetching #{url}", fn ->
        Fetch.fetch_url(url, Keyword.merge(opts, fetch_opts))
      end)

    data
    |> handle_response(state)
  end

  def handle_response({:ok, body}, %{module: state_module, sync_timeout: sync_timeout} = state) do
    _ =
      Logger.debug(fn ->
        "#{__MODULE__} #{state_module} received body of length #{byte_size(body)}"
      end)

    debug_time("#{state_module} new state", fn -> state_module.new_state(body, sync_timeout) end)

    state
    |> reset_retries
    |> schedule_update
  end

  def handle_response(:unmodified, %{module: state_module} = state) do
    _ = Logger.debug(fn -> "#{__MODULE__} #{state_module} received unmodified" end)

    state
    |> reset_retries
    |> schedule_update
  end

  def handle_response({:error, error}, %{module: state_module, retries: retries} = state) do
    max_seconds = min(trunc(:math.pow(2, retries + 1)) + 1, @max_retry_duration)
    timeout = :rand.uniform(max_seconds)
    logger = logger_with_level_for_error(error)

    _ =
      logger.(fn ->
        Enum.join(
          [
            __MODULE__,
            state_module,
            "received error:",
            inspect(error),
            "retrying after #{timeout} (#{retries})"
          ],
          " "
        )
      end)

    state = reset_retries(state, retries + 1)
    {:noreply, state, :timer.seconds(timeout)}
  end

  defp reset_retries(state, value \\ 0) do
    %{state | retries: value}
  end

  defp schedule_update(%{interval: interval} = state) when interval != nil do
    {:noreply, state, interval}
  end

  defp schedule_update(state) do
    {:noreply, state}
  end

  defp debug_time(description, func) do
    State.Logger.debug_time(func, fn milliseconds ->
      "#{__MODULE__} #{description} took #{milliseconds}ms"
    end)
  end

  defp logger_with_level_for_error(%HTTPoison.Error{reason: :timeout}), do: &Logger.warn/1
  defp logger_with_level_for_error(_), do: &Logger.error/1
end
