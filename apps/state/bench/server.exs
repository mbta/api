defmodule State.ServerBench do
  use Benchfella

  @schedule %Model.Schedule{
    trip_id: "trip",
    stop_id: "stop",
    position: :first}

  @items (List.duplicate(@schedule, 1000) ++ [%Model.Schedule{trip_id: "other", stop_id: "other"}])
  |> Enum.with_index()
  |> Enum.map(fn {schedule, index} -> %{schedule | trip_id: Integer.to_string(index)} end)

  def setup_all do
    Application.ensure_all_started(:events)
    Application.ensure_all_started(:mnesia)
    State.Schedule.start_link
    State.Schedule.new_state(@items)
    Logger.configure(level: :warning)
    {:ok, :ignored}
  end

  bench "all" do
    State.Schedule.all
  end

  bench "single primary" do
    State.Schedule.by_trip_id("other")
  end

  bench "multi primary" do
    State.Schedule.by_trip_ids(~w(1 2 3 4 5)s)
  end

  bench "single secondary" do
    State.Schedule.by_stop_id("other")
  end

  bench "single secondary w/ duplicates" do
    State.Schedule.by_stop_id("stop")
  end

  bench "multi secondary" do
    State.Schedule.by_stop_ids(~w(stop other)s)
  end

  bench "single match on primary" do
    State.Schedule.match(%{trip_id: "other", stop_id: "other"}, :trip_id)
  end

  bench "single match secondary" do
    State.Schedule.match(%{trip_id: "other", stop_id: "other"}, :stop_id)
  end

  bench "single match single primary" do
    State.Schedule.match(%{trip_id: "other"}, :trip_id)
  end

  bench "single match single secondary" do
    State.Schedule.match(%{stop_id: "other"}, :stop_id)
  end

  bench "single select" do
    State.Schedule.select([%{trip_id: "other", stop_id: "other"}])
  end

  bench "multi match" do
    for trip_id <- 0..5 do
      State.Schedule.match(%{trip_id: Integer.to_string(trip_id), stop_id: "stop"}, :trip_id)
    end
  end

  bench "multi match index" do
    for trip_id <- 0..5 do
      State.Schedule.match(%{trip_id: Integer.to_string(trip_id), stop_id: "stop"}, :stop_id)
    end
  end

  bench "multi select" do
    matchers = for trip_id <- 0..5 do
      %{trip_id: Integer.to_string(trip_id), stop_id: "stop"}
    end
    State.Schedule.select(matchers)
  end

  bench "multi select primary" do
    matchers = for trip_id <- 0..5 do
      %{trip_id: Integer.to_string(trip_id), stop_id: "stop"}
    end
    State.Schedule.select(matchers, :trip_id)
  end

  bench "multi select single" do
    matchers = for trip_id <- 0..5 do
      %{trip_id: Integer.to_string(trip_id)}
    end
    State.Schedule.select(matchers, :trip_id)
  end

  bench "multi select no primary" do
    State.Schedule.select([%{stop_id: "stop"}, %{stop_id: "other"}])
  end

  bench "state enum" do
    State.Schedule.new_state(@items)
  end
end
