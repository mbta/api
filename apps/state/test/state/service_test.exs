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
        schedule_typicality: 1,
        rating_start_date: ~D[2018-12-22],
        rating_end_date: ~D[2019-03-14],
        rating_description: "Winter"
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

    service = %Service{
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
      removed_dates_notes: [nil],
      rating_start_date: ~D[2018-12-22],
      rating_end_date: ~D[2019-03-14],
      rating_description: "Winter"
    }

    assert State.Service.by_id("service") == service

    trip = %Model.Trip{
      block_id: "block_id",
      id: "trip_id",
      route_id: "1",
      direction_id: 1,
      service_id: "service",
      name: "name"
    }

    State.Trip.new_state([trip])

    assert State.Service.by_route_id("1") == [service]
    assert State.Service.by_route_id("2") == []
    assert State.Service.by_route_ids(["1"]) == [service]
    assert State.Service.by_route_ids(["1", "2"]) == [service]
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
        schedule_typicality: nil,
        rating_start_date: nil,
        rating_end_date: nil,
        rating_description: nil
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
             removed_dates_notes: [],
             rating_start_date: nil,
             rating_end_date: nil,
             rating_description: nil
           }
  end
end
