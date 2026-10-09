defmodule ApiWeb.HackneyLogFilter do
  @moduledoc """
  A `:logger` primary filter that drops supervisor reports for hackney
  connections killed by hackney itself.

  Only reports logged as "Child :hackney_conn of Supervisor :hackney_conn_sup terminated"
  with reason `:killed` are dropped
  any other `hackney_conn` exit, such as a crash, is still logged.
  """

  def filter(log_event, _opts) do
    case log_event do
      %{msg: {:report, %{label: {:supervisor, :child_terminated}, report: report}}} ->
        if report[:supervisor] == {:local, :hackney_conn_sup} and report[:reason] == :killed do
          :stop
        else
          :ignore
        end

      _ ->
        :ignore
    end
  end
end
