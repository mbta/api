defmodule Health.Checkers.RunQueue do
  @moduledoc """
  Health check which makes sure the Erlang [Run
  Queue](http://erlang.org/doc/man/erlang.html#statistics-1) is reasonably
  low.
  """
  require Logger

  def current do
    [run_queue: queue_size()]
  end

  def healthy? do
    h? = queue_size() < 50

    _ = log_processes(h?, Logger.level())

    h?
  end

  defp queue_size do
    :erlang.statistics(:run_queue)
  end

  def log_processes(false, level) when level in [:info, :debug] do
    for line <- log_lines() do
      _ = Logger.info(line)
    end

    :logged
  end

  def log_processes(_, _) do
    :ignored
  end

  def log_lines do
    for pid <- Process.list() do
      "process_info pid=#{inspect(pid)} #{log_info(pid)}"
    end
  end

  def log_info(pid) do
    info =
      Process.info(
        pid,
        ~w(current_function initial_call status message_queue_len priority total_heap_size heap_size stack_size reductions dictionary)a
      )

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
