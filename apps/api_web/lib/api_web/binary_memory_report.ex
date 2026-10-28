defmodule ApiWeb.BinaryMemoryReport do
  @moduledoc """
  Temporary diagnostic for the binary memory leak (Oct 2026).

  Periodically logs the processes referencing the most off-heap binary memory,
  then garbage collects the top few and logs how much binary memory was freed.
  A large drop means processes are slow to GC; little or no drop means
  something is holding references to the binaries.

  Enabled by setting `config :api_web, ApiWeb.BinaryMemoryReport, interval: ms`.
  """
  use GenServer
  require Logger

  @top_n 10
  @gc_top_n 3

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    interval = Keyword.fetch!(opts, :interval)
    schedule(interval)
    {:ok, interval}
  end

  @impl GenServer
  def handle_info(:report, interval) do
    report()
    schedule(interval)
    {:noreply, interval, :hibernate}
  end

  def handle_info(_, interval), do: {:noreply, interval}

  defp schedule(interval), do: Process.send_after(self(), :report, interval)

  def report do
    total_before = :erlang.memory(:binary)

    all = Enum.map(Process.list(), &{&1, binary_bytes(&1)})
    referenced_by_processes = Enum.reduce(all, 0, fn {_, bytes}, acc -> acc + bytes end)

    Logger.info(
      "binary_memory_report total_binary_mb=#{mb(total_before)} referenced_by_processes_mb=#{mb(referenced_by_processes)}"
    )

    top =
      all
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(@top_n)

    top
    |> Enum.with_index(1)
    |> Enum.each(fn {{pid, bytes}, rank} ->
      Logger.info(
        "binary_memory_report rank=#{rank} pid=#{inspect(pid)} binary_mb=#{mb(bytes)} #{describe(pid)}"
      )
    end)

    top
    |> Enum.take(@gc_top_n)
    |> Enum.each(fn {pid, _} -> :erlang.garbage_collect(pid) end)

    total_after = :erlang.memory(:binary)

    Logger.info(
      "binary_memory_report gc_top=#{@gc_top_n} total_binary_mb_before=#{mb(total_before)} total_binary_mb_after=#{mb(total_after)} process_count=#{length(Process.list())}"
    )

    report_ports()
    report_ets()
  end

  # Data written to a socket that the client hasn't read yet sits in the
  # port's output queue. It counts as binary memory but belongs to no process.
  defp report_ports do
    ports =
      Port.list()
      |> Enum.map(fn port ->
        case :erlang.port_info(port, :queue_size) do
          {:queue_size, bytes} -> {port, bytes}
          _ -> {port, 0}
        end
      end)

    queued = Enum.filter(ports, fn {_, bytes} -> bytes > 0 end)
    total = Enum.reduce(queued, 0, fn {_, bytes}, acc -> acc + bytes end)

    Logger.info(
      "binary_memory_report ports=#{length(ports)} ports_with_queue=#{length(queued)} total_port_queue_mb=#{mb(total)}"
    )

    queued
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(@top_n)
    |> Enum.with_index(1)
    |> Enum.each(fn {{port, bytes}, rank} ->
      Logger.info(
        "binary_memory_report port_rank=#{rank} port=#{inspect(port)} queue_mb=#{mb(bytes)} #{describe_port(port)}"
      )
    end)
  end

  defp describe_port(port) do
    peer =
      case :inet.peername(port) do
        {:ok, {ip, p}} -> "#{:inet.ntoa(ip)}:#{p}"
        _ -> "unknown"
      end

    case :erlang.port_info(port, :connected) do
      {:connected, pid} ->
        "peer=#{peer} request_id=#{request_id(pid)} owner_pid=#{inspect(pid)} #{describe(pid)}"

      _ ->
        "peer=#{peer} owner=none"
    end
  end

  # the request_id lets us find the request (path, api key) in the access logs
  defp request_id(pid) do
    with {:dictionary, dict} <- Process.info(pid, :dictionary),
         %{} = metadata <- Keyword.get(dict, :"$logger_metadata$"),
         id when is_binary(id) <- Map.get(metadata, :request_id) do
      id
    else
      _ -> "none"
    end
  end

  # Large binaries stored in ETS/mnesia tables also belong to no process.
  defp report_ets do
    word = :erlang.system_info(:wordsize)

    :ets.all()
    |> Enum.map(fn tab ->
      {tab, :ets.info(tab, :name), :ets.info(tab, :size), :ets.info(tab, :memory)}
    end)
    |> Enum.reject(fn {_, _, _, memory} -> memory == :undefined end)
    |> Enum.sort_by(fn {_, _, _, memory} -> memory end, :desc)
    |> Enum.take(@top_n)
    |> Enum.with_index(1)
    |> Enum.each(fn {{_tab, name, size, memory}, rank} ->
      Logger.info(
        "binary_memory_report ets_rank=#{rank} table=#{inspect(name)} rows=#{size} ets_mb=#{mb(memory * word)}"
      )
    end)
  end

  defp binary_bytes(pid) do
    case Process.info(pid, :binary) do
      {:binary, bins} ->
        bins |> Enum.uniq_by(&elem(&1, 0)) |> Enum.reduce(0, &(elem(&1, 1) + &2))

      nil ->
        0
    end
  end

  defp describe(pid) do
    case Process.info(pid, [:registered_name, :current_function, :message_queue_len, :memory]) do
      nil ->
        "dead=true"

      info ->
        initial_call =
          case :proc_lib.translate_initial_call(pid) do
            {m, f, a} -> "#{inspect(m)}.#{f}/#{a}"
            other -> inspect(other)
          end

        name =
          case info[:registered_name] do
            [] -> "none"
            name -> inspect(name)
          end

        {m, f, a} = info[:current_function] || {:unknown, :unknown, 0}

        "name=#{name} initial_call=#{initial_call} current_function=#{inspect(m)}.#{f}/#{a} " <>
          "message_queue_len=#{info[:message_queue_len]} heap_mb=#{mb(info[:memory])}"
    end
  end

  defp mb(bytes), do: Float.round(bytes / 1_048_576, 1)
end
