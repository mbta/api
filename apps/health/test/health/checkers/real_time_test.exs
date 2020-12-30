defmodule Health.Checkers.RealTimeTest do
  use ExUnit.Case
  import Health.Checkers.RealTime

  defp set_updated_timestamps do
    State.Metadata.state_updated(
      State.Prediction,
      DateTime.from_naive!(~N[2020-12-30 15:00:00], "Etc/UTC")
    )

    State.Metadata.state_updated(
      State.Vehicle,
      DateTime.from_naive!(~N[2020-12-30 15:05:00], "Etc/UTC")
    )
  end

  defp earlier_time do
    DateTime.from_naive!(~N[2020-12-30 15:14:00], "Etc/UTC")
  end

  defp later_time do
    DateTime.from_naive!(~N[2020-12-30 15:16:00], "Etc/UTC")
  end

  describe "current/0" do
    test "returns current vehicle and prediction timestamps" do
      set_updated_timestamps()

      assert current() == [
               prediction: DateTime.from_naive!(~N[2020-12-30 15:00:00], "Etc/UTC"),
               vehicle: DateTime.from_naive!(~N[2020-12-30 15:05:00], "Etc/UTC")
             ]
    end
  end

  describe "healthy?/1" do
    test "returns healthy when both predictions and vehicles are recent" do
      set_updated_timestamps()
      assert healthy?(&earlier_time/0)
    end

    test "returns unhealthy when one of predictions or vehicles are stale" do
      set_updated_timestamps()
      refute healthy?(&later_time/0)
    end
  end
end
