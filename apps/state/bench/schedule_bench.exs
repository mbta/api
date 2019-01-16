defmodule State.ScheduleBench do
  use Benchfella

  @schedule %Model.Schedule{
    trip_id: "trip",
    stop_id: "stop",
    position: :first}

  def setup_all do
    Application.ensure_all_started(:events)
    State.Schedule.start_link
    @schedule
    |> expand_schedule(30_000)
    |> State.Schedule.new_state

    {:ok, pid}
  end

  def teardown_all(pid) do
    State.Schedule.stop
  end

  defp expand_schedule(schedule, count) do
    [schedule|do_expand_schedule(schedule, count)]
  end
  defp do_expand_schedule(_, 0), do: []
  defp do_expand_schedule(%{trip_id: trip_id} = schedule, count) do
    new_schedule = case rem(count, 3) do
                     0 ->  %{schedule | trip_id: "#{trip_id}_#{count}"}
                     1 -> schedule
                     2 ->  %{schedule | stop_id: "#{trip_id}_#{count}"}
                   end
    [new_schedule|do_expand_schedule(schedule, count - 1)]
  end

  bench "by_trip_id" do
    "trip"
    |> State.Schedule.by_trip_id
    |> Enum.filter(&(&1.position == :first))
  end

  bench "match" do
    #[@schedule] =
    State.Schedule.match(%{trip_id: "trip", position: :first}, :trip_id)
  end
end
