defmodule State.ServiceByDateTest do
  @moduledoc false
  use ExUnit.Case
  use Timex
  import State.ServiceByDate

  @start_date Timex.now() |> Timex.beginning_of_week(:sun) |> Timex.to_date()
  @end_date @start_date |> Timex.shift(days: 7)
  @weekday_date @start_date |> Timex.shift(days: 2)
  @friday_date @start_date |> Timex.shift(days: 5)
  @saturday_date @start_date |> Timex.shift(days: 6)

  @weekday %Model.Service{
    id: "weekday",
    start_date: @start_date,
    end_date: @end_date,
    valid_days: [1, 2, 3, 4, 5]
  }
  @fri_sat %Model.Service{
    id: "fri_sat",
    start_date: @start_date,
    end_date: @end_date,
    valid_days: [5, 6]
  }

  defp services(_) do
    State.Service.new_state([@weekday, @fri_sat])
  end

  describe "by_date" do
    setup [:services]

    test "returns the service IDs valid on a given date" do
      assert State.ServiceByDate.by_date(@weekday_date) == ["weekday"]

      assert @friday_date |> State.ServiceByDate.by_date() |> Enum.sort() ==
               ["weekday", "fri_sat"] |> Enum.sort()

      assert State.ServiceByDate.by_date(@saturday_date) == ["fri_sat"]
      assert State.ServiceByDate.by_date(@end_date) == []
    end
  end

  describe "valid?/1" do
    setup :services

    test "returns true if the service ID is valid for the given date" do
      assert valid?("weekday", @weekday_date)
      assert valid?("weekday", @friday_date)
      refute valid?("weekday", @saturday_date)
      refute valid?("weekday", @end_date)
      refute valid?("fri_sat", @weekday_date)
      assert valid?("fri_sat", @friday_date)
      assert valid?("fri_sat", @saturday_date)
      refute valid?("fri_sat", @end_date)
    end
  end

  describe "service_with_date" do
    test "returns a list of tuples {{year, month, day}, service_id}" do
      assert State.ServiceByDate.service_with_date([@weekday, @fri_sat]) == [
               {@start_date |> Timex.shift(days: 1) |> Date.to_erl(), "weekday"},
               {@start_date |> Timex.shift(days: 2) |> Date.to_erl(), "weekday"},
               {@start_date |> Timex.shift(days: 3) |> Date.to_erl(), "weekday"},
               {@start_date |> Timex.shift(days: 4) |> Date.to_erl(), "weekday"},
               {@start_date |> Timex.shift(days: 5) |> Date.to_erl(), "weekday"},
               {@start_date |> Timex.shift(days: 5) |> Date.to_erl(), "fri_sat"},
               {@start_date |> Timex.shift(days: 6) |> Date.to_erl(), "fri_sat"}
             ]
    end

    test "handles services active on start/end dates" do
      start = %Model.Service{
        id: "start",
        start_date: @start_date,
        end_date: @end_date,
        added_dates: [@start_date]
      }

      stop = %Model.Service{
        id: "stop",
        start_date: @start_date,
        end_date: @end_date,
        added_dates: [@end_date]
      }

      assert State.ServiceByDate.service_with_date([start, stop]) == [
               {@start_date |> Date.to_erl(), "start"},
               {@end_date |> Date.to_erl(), "stop"}
             ]
    end

    test "handles services with additional dates before the starting date" do
      service = %Model.Service{
        id: "service",
        start_date: @friday_date,
        end_date: @saturday_date,
        added_dates: [@weekday_date]
      }

      assert State.ServiceByDate.service_with_date([service]) == [
               {Date.to_erl(@weekday_date), "service"}
             ]
    end

    test "handles services with additional dates after the ending date" do
      service = %Model.Service{
        id: "service",
        start_date: @start_date,
        end_date: @friday_date,
        added_dates: [@saturday_date]
      }

      assert State.ServiceByDate.service_with_date([service]) == [
               {Date.to_erl(@saturday_date), "service"}
             ]
    end
  end

  describe "crash" do
    @tag timeout: 1_000
    test "rebuilds properly if it's restarted" do
      State.Service.new_state([@weekday, @fri_sat])
      GenServer.stop(State.ServiceByDate)
      await_size(State.ServiceByDate)
    end

    defp await_size(module) do
      # waits for the module to have a size > 0: eventually the test will
      # timeout if this doesn't happen
      if module.size() > 0 do
        :ok
      else
        await_size(module)
      end
    end
  end
end
