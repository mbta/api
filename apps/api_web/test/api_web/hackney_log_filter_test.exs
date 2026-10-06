defmodule ApiWeb.HackneyLogFilterTest do
  # changes global :logger configuration
  use ExUnit.Case, async: false

  alias ApiWeb.HackneyLogFilter

  defp child_terminated(supervisor, reason) do
    %{
      level: :error,
      meta: %{domain: [:otp, :sasl]},
      msg:
        {:report,
         %{
           label: {:supervisor, :child_terminated},
           report: [
             supervisor: supervisor,
             errorContext: :child_terminated,
             reason: reason,
             offender: [id: :hackney_conn, restart_type: :temporary]
           ]
         }}
    }
  end

  describe "filter/2" do
    test "drops hackney_conn children killed by hackney" do
      assert :stop =
               HackneyLogFilter.filter(child_terminated({:local, :hackney_conn_sup}, :killed), [])
    end

    test "keeps hackney_conn children that exit for any other reason" do
      event = child_terminated({:local, :hackney_conn_sup}, {:badmatch, :error})
      assert :ignore = HackneyLogFilter.filter(event, [])
    end

    test "keeps killed children of other supervisors" do
      event = child_terminated({:local, :some_other_sup}, :killed)
      assert :ignore = HackneyLogFilter.filter(event, [])
    end

    test "keeps other log events" do
      event = %{level: :error, meta: %{}, msg: {:string, "hackney_conn_sup killed"}}
      assert :ignore = HackneyLogFilter.filter(event, [])
    end

    test "matches the report hackney actually produces" do
      parent = self()
      probe = fn event, _ -> send(parent, {:log_event, event}) && :ignore end
      :ok = :logger.add_primary_filter(:hackney_log_filter_test_probe, {probe, []})
      on_exit(fn -> :logger.remove_primary_filter(:hackney_log_filter_test_probe) end)

      {:ok, _} = Application.ensure_all_started(:hackney)

      {:ok, pid} =
        :hackney_conn_sup.start_conn(%{host: ~c"localhost", port: 1, transport: :hackney_tcp})

      Process.exit(pid, :kill)

      assert_receive {:log_event,
                      %{msg: {:report, %{label: {:supervisor, :child_terminated}}}} = event}

      assert :stop = HackneyLogFilter.filter(event, [])
    end
  end

  test "is installed as a primary filter when the application starts" do
    assert {_, {filter, []}} =
             List.keyfind(:logger.get_primary_config().filters, :hackney_conn_killed, 0)

    assert filter == (&HackneyLogFilter.filter/2)
  end
end
