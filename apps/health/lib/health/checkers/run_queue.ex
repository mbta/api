defmodule Health.Checkers.RunQueue do
  @moduledoc """
  Health check for monitoring the Erlang [Run
  Queue](http://erlang.org/doc/man/erlang.html#statistics-1).

  This check always returns healthy as we don't want to kill tasks based on the run queue length.
  Instead it logs the maximum run queue length across all schedulers for monitoring purposes.
  """
  require Logger

  def current do
    [run_queue: max_queue_length()]
  end

  def healthy? do
    max_length = max_queue_length()
    _ = Logger.info("run_queue_check max_run_queue_length=#{max_length}")
    true
  end

  defp max_queue_length do
    Enum.max(:erlang.statistics(:run_queue_lengths))
  end
end
