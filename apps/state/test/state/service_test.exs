defmodule State.ServiceTest do
  use ExUnit.Case
  use Timex

  alias Model.Service
  alias Parse.Calendar
  alias Parse.CalendarAttributes
  alias Parse.CalendarDates

  setup do
    State.Service.new_state([])
    :ok
  end

  test "init" do
    assert {:ok, %{data: _, last_updated: nil}} = State.Service.init([])
  end

  test "returns nil for unknown services" do
    assert State.Service.by_id("1") == nil
  end

  test "it can add a service and query it" do
    calendar = [
      %Calendar{
        service_id: "service",
        days: [1, 2, 5],
        start_date: Timex.today(),
        end_date: Timex.shift(Timex.today(), days: 2)
      }
    ]

    calendar_attributes = [
      %CalendarAttributes{
        service_id: "service",
        description: "description",
        schedule_name: "name",
        schedule_type: "type",
        schedule_typicality: 1
      }
    ]

    calendar_dates = [
      %CalendarDates{
        service_id: "service",
        date: Timex.today(),
        added: true,
        holiday_name: "This Code's Birthday"
      },
      %CalendarDates{
        service_id: "service",
        date: Timex.shift(Timex.today(), days: 1),
        added: false,
        holiday_name: ""
      }
    ]

    State.Service.new_state({calendar, calendar_attributes, calendar_dates})

    assert State.Service.by_id("service") == %Service{
             id: "service",
             start_date: Timex.today(),
             end_date: Timex.shift(Timex.today(), days: 2),
             valid_days: [1, 2, 5],
             description: "description",
             schedule_name: "name",
             schedule_type: "type",
             schedule_typicality: 1,
             added_dates: [Timex.today()],
             added_dates_notes: ["This Code's Birthday"],
             removed_dates: [Timex.shift(Timex.today(), days: 1)],
             removed_dates_notes: [nil]
           }
  end

  test "it can add services which are only present in CalendarDates" do
    today = Timex.today()
    tomorrow = Timex.shift(today, days: 1)
    calendar = []
    calendar_attributes = []

    calendar_dates = [
      %CalendarDates{
        service_id: "service",
        date: today,
        added: true
      },
      %CalendarDates{
        service_id: "service",
        date: tomorrow,
        added: true
      }
    ]

    State.Service.new_state({calendar, calendar_attributes, calendar_dates})

    assert State.Service.by_id("service") == %Service{
             id: "service",
             start_date: today,
             end_date: tomorrow,
             valid_days: [],
             description: nil,
             schedule_name: nil,
             schedule_type: nil,
             schedule_typicality: 0,
             added_dates: [today, tomorrow],
             added_dates_notes: [nil, nil],
             removed_dates: [],
             removed_dates_notes: []
           }
  end

  test "it handles missing fields in calendar_attributes" do
    today = Timex.today()
    tomorrow = Timex.shift(today, days: 1)

    calendar = [
      %Calendar{
        service_id: "service",
        days: [1, 2, 5],
        start_date: today,
        end_date: tomorrow
      }
    ]

    calendar_attributes = [
      %CalendarAttributes{
        service_id: "service",
        description: nil,
        schedule_name: nil,
        schedule_type: nil,
        schedule_typicality: nil
      }
    ]

    calendar_dates = []
    State.Service.new_state({calendar, calendar_attributes, calendar_dates})

    assert State.Service.by_id("service") == %Service{
             id: "service",
             start_date: today,
             end_date: tomorrow,
             valid_days: [1, 2, 5],
             description: nil,
             schedule_name: nil,
             schedule_type: nil,
             schedule_typicality: 0,
             added_dates: [],
             added_dates_notes: [],
             removed_dates: [],
             removed_dates_notes: []
           }
  end
end
