defmodule ApiWeb.RateLimiter.RateLimiterConcurrent do
  @moduledoc """
  Rate limits a user's concurrent connections based on their API key or by their IP address if no
  API key is provided. Split by static and event-stream requests.
  """

  use GenServer
  require Logger

  @rate_limit_concurrent_config Application.compile_env!(:api_web, :rate_limiter_concurrent)

  def start_link([]), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    connection_opts = Keyword.fetch!(@rate_limit_concurrent_config, :connection_opts)

    {:ok, pid} = if memcache?(), do: Memcache.start_link(connection_opts), else: {:ok, nil}
    {:ok, %{memcache_pid: pid, uuid: UUID.uuid1()}}
  end

  defp lookup(%ApiWeb.User{} = user, event_stream?) do
    type = if event_stream?, do: "event_stream", else: "static"
    key = "concurrent_#{user.id}_#{type}"

    {
      type,
      key
    }
  end

  def get_pid_key(pid) do
    sub_key = pid |> :erlang.pid_to_list() |> to_string
    get_uuid() <> sub_key
  end

  defp get_uuid do
    {:ok, uuid} = GenServer.call(__MODULE__, :get_uuid)
    uuid
  end

  defp get_current_unix_ts do
    System.system_time(:second)
  end

  defp get_heartbeat_tolerance do
    Keyword.fetch!(@rate_limit_concurrent_config, :heartbeat_tolerance)
  end

  def get_locks(%ApiWeb.User{} = user, event_stream?) do
    if enabled?() do
      current_timestamp = get_current_unix_ts()
      heartbeat_tolerance = get_heartbeat_tolerance()
      {_type, key} = lookup(user, event_stream?)
      {:ok, locks} = GenServer.call(__MODULE__, {:memcache_get, key, %{}})
      # Check if any expired, and remove:
      valid_locks =
        :maps.filter(
          fn _, timestamp ->
            timestamp + heartbeat_tolerance >= current_timestamp
          end,
          locks
        )

      if valid_locks != locks, do: GenServer.call(__MODULE__, {:memcache_set, key, valid_locks})
      valid_locks
    else
      %{}
    end
  end

  def check_concurrent_rate_limit(user, event_stream?) do
    active_connections = user |> get_locks(event_stream?) |> Map.keys() |> length

    limit =
      case {event_stream?, user.type} do
        {true, :registered} ->
          if user.streaming_concurrent_limit >= 0,
            do:
              max(
                user.streaming_concurrent_limit || 0,
                Keyword.fetch!(
                  @rate_limit_concurrent_config,
                  :max_registered_streaming
                )
              ),
            else: user.streaming_concurrent_limit

        {false, :registered} ->
          if user.static_concurrent_limit >= 0,
            do:
              max(
                user.static_concurrent_limit || 0,
                Keyword.fetch!(
                  @rate_limit_concurrent_config,
                  :max_registered_static
                )
              ),
            else: user.static_concurrent_limit

        {true, :anon} ->
          Keyword.fetch!(
            @rate_limit_concurrent_config,
            :max_anon_streaming
          )

        {false, :anon} ->
          Keyword.fetch!(
            @rate_limit_concurrent_config,
            :max_anon_static
          )
      end

    remaining = limit - active_connections
    at_limit? = remaining <= 0
    {at_limit?, remaining, limit}
  end

  def add_lock(%ApiWeb.User{} = user, pid, event_stream?) do
    if enabled?() do
      {_type, key} = lookup(user, event_stream?)
      pid_key = get_pid_key(pid)
      timestamp = get_current_unix_ts()

      Logger.info(
        "#{__MODULE__} event=add_lock user=#{inspect(user)} pid_key=#{pid_key} key=#{key} timestamp=#{timestamp}"
      )

      locks = user |> get_locks(event_stream?) |> Map.put(pid_key, timestamp)

      Logger.info(
        "#{__MODULE__} event=add_lock_after user=#{inspect(user)} pid_key=#{pid_key} key=#{key} timestamp=#{timestamp} locks=#{inspect(locks)}"
      )

      GenServer.call(__MODULE__, {:memcache_set, key, locks})
    end

    nil
  end

  def remove_lock(
        %ApiWeb.User{} = user,
        pid,
        event_stream?,
        pid_key \\ nil
      ) do
    if enabled?() do
      {_type, key} = lookup(user, event_stream?)
      pid_key = if pid_key, do: pid_key, else: get_pid_key(pid)
      locks_before = get_locks(user, event_stream?)
      locks = locks_before |> Map.delete(pid_key)

      Logger.info(
        "#{__MODULE__} event=remove_lock user_id=#{user.id} pid_key=#{pid_key} key=#{key}"
      )

      GenServer.call(__MODULE__, {:memcache_set, key, locks})

      Logger.info(
        "#{__MODULE__} event=remove_lock_after user_id=#{user.id} pid_key=#{pid_key} key=#{key} locks=#{inspect(locks)}"
      )
    end

    nil
  end

  def enabled? do
    Keyword.fetch!(@rate_limit_concurrent_config, :enabled) == True
  end

  def memcache? do
    Keyword.fetch!(@rate_limit_concurrent_config, :memcache) == True
  end

  def handle_call(:get_uuid, _from, state) do
    {:reply, {:ok, state.uuid}, state}
  end

  def handle_call({:memcache_get, key, default_value}, _from, state) do
    {:reply,
     {:ok,
      case Memcache.get(state.memcache_pid, key) do
        {:ok, result} -> result
        _ -> default_value
      end}, state}
  end

  def handle_call({:memcache_set, key, value}, _from, state) do
    {:reply, {:ok, Memcache.set(state.memcache_pid, key, value)}, state}
  end
end
