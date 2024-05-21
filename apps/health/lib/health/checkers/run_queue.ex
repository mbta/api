defmodule Health.Checkers.RunQueue do
  @moduledoc """
  Health check which makes sure the Erlang [Run
  Queue](http://erlang.org/doc/man/erlang.html#statistics-1) is reasonably
  low.
  """
  require Logger
  @max_run_queue_length 100

  def current do
    [run_queue: queue_size()]
  end

  def healthy? do
    h? = queue_size() <= @max_run_queue_length

    _ = log_processes(h?, Logger.level())

    h?
  end

  defp queue_size do
    :erlang.statistics(:run_queue)
  end

  def log_processes(false, level) when level in [:info, :debug] do
    spawn(fn ->
      for line <- log_lines() do
        _ = Logger.info(line)
      end
    end)

    :logged
  end

  def log_processes(_, _) do
    :ignored
  end

  def log_lines do
    start_time = System.monotonic_time()

    for pid <- Process.list() do
      # lt short for log time
      "process_info pid=#{inspect(pid)} lt=#{start_time} #{log_info(pid)}"
    end
  end

  def log_info(pid) do
    info =
      Process.info(
        pid,
        ~w(current_function initial_call status message_queue_len priority total_heap_size heap_size stack_size reductions dictionary registered_name memory)a
      )

    log_info_iodata(info)
  end

  defp log_info_iodata(info) when is_list(info) do
    info =
      if initial_call = info[:dictionary][:"$initial_call"] do
        Keyword.put(info, :initial_call, initial_call)
      else
        info
      end

    info = Keyword.delete(info, :dictionary)

    for {k, v} <- info do
      [Atom.to_string(k), "=", pid_log(v), " "]
    end
  end

  defp log_info_iodata(nil) do
    ["status=dead"]
  end

  defp pid_log({m, f, a}) when is_atom(m) and is_atom(f) and a >= 0 do
    [?", Atom.to_string(m), ?., Atom.to_string(f), ?/, Integer.to_string(a), ?"]
  end

  defp pid_log(atom) when is_atom(atom) do
    Atom.to_string(atom)
  end

  defp pid_log(other) do
    inspect(other)
  end
end
