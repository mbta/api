defmodule State.SimpleBench do
  use Benchfella

  @schedule %Model.Schedule{
    trip_id: "trip",
    stop_id: "stop",
    position: :first}

  def setup_all do
    State.Schedule.new_state([@schedule])
  end

  bench "by_trip_id" do
    State.Schedule.by_trip_id("trip") == [@schedule]
  end

  bench "match" do
    State.Schedule.match(%{trip_id: "trip"}) == [@schedule]
  end
end
