defmodule State.Logger do
  @moduledoc """
  Helpers for logging about `State`
  """

  require Logger

  # Don't use `:erlang.convert_time_unit/3` directly on the `microseconds` from `:timer.tc/1` because
  # `:erlang.convert_time_unit/3` takes floor of conversion, so we'd lose fractional milliseconds.
  @microseconds_per_millisecond :erlang.convert_time_unit(1, :millisecond, :microsecond)

  @doc """
  Measures time of `function` and logs
  """
  @spec debug_time(measured :: (() -> result), message :: (milliseconds :: float -> String.t())) ::
          result
        when result: any
  def debug_time(measured, message) when is_function(measured, 0) and is_function(message, 1) do
    {microseconds, result} = :timer.tc(measured)
    _ = Logger.debug(fn -> message.(microseconds / @microseconds_per_millisecond) end)

    result
  end
end
