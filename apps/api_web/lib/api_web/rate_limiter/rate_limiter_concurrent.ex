defmodule ApiWeb.RateLimiter.RateLimiterConcurrent do
  @moduledoc """
  Rate limits a user's concurrent connections based on their API key or by their IP address if no
  API key is provided. Split by static and event-stream requests.
  """

  use GenServer
  require Logger
  alias ApiWeb.RateLimiter.Memcache.Supervisor

  @rate_limit_concurrent_config Application.compile_env!(:api_web, :rate_limiter_concurrent)
  @uuid_key "ApiWeb.RateLimiter.RateLimiterConcurrent_uuid"
  def start_link([]), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    uuid = UUID.uuid1()
    :persistent_term.put(@uuid_key, uuid)
    {:ok, %{uuid: uuid}}
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
    :persistent_term.get(@uuid_key)
  end

  defp get_current_unix_ts do
    System.system_time(:second)
  end

  defp get_heartbeat_tolerance do
    Keyword.fetch!(@rate_limit_concurrent_config, :heartbeat_tolerance)
  end

  def mutate_locks(%ApiWeb.User{} = user, event_stream?, before_commit \\ fn value -> value end) do
    if enabled?() do
      current_timestamp = get_current_unix_ts()
      heartbeat_tolerance = get_heartbeat_tolerance()
      {_type, key} = lookup(user, event_stream?)

      memcache_update(key, %{}, fn locks ->
        valid_locks =
          :maps.filter(
            fn _, timestamp ->
              timestamp + heartbeat_tolerance >= current_timestamp
            end,
            locks
          )

        before_commit.(valid_locks)
      end)
    else
      {:ok, %{}}
    end
  end

  @spec check_concurrent_rate_limit(ApiWeb.User.t(), boolean()) ::
          {false, number(), number()} | {true, number(), number()}
  def check_concurrent_rate_limit(user, event_stream?) do
    {:ok, locks} = user |> mutate_locks(event_stream?)
    active_connections = locks |> Map.keys() |> length

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

      locks =
        user |> mutate_locks(event_stream?, fn locks -> Map.put(locks, pid_key, timestamp) end)

      Logger.info(
        "#{__MODULE__} event=add_lock_after user=#{inspect(user)} pid_key=#{pid_key} key=#{key} timestamp=#{timestamp} locks=#{inspect(locks)}"
      )
    end

    nil
  end

  def remove_lock(
        %ApiWeb.User{} = user,
        pid,
        event_stream?,
        pid_key \\ nil
      ) do
    if enabled?() and memcache?() do
      {_type, key} = lookup(user, event_stream?)
      pid_key = if pid_key, do: pid_key, else: get_pid_key(pid)

      {:ok, _locks} =
        mutate_locks(user, event_stream?, fn locks -> Map.delete(locks, pid_key) end)

      Logger.info(
        "#{__MODULE__} event=remove_lock user_id=#{user.id} pid_key=#{pid_key} key=#{key}"
      )
    end

    nil
  end

  def enabled? do
    Keyword.fetch!(@rate_limit_concurrent_config, :enabled)
  end

  def memcache? do
    Keyword.fetch!(@rate_limit_concurrent_config, :memcache)
  end

  def memcache_update(key, default_value, update_fn) do
    Memcache.cas(Supervisor.random_child(), key, update_fn, default: default_value)
  end
end
