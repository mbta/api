defmodule Parse.CalendarDatesTest do
  use ExUnit.Case, async: true

  alias Parse.CalendarDates
  use Timex

  test "parses calendar dates" do
    blob = """
    "service_id","date","exception_type","holiday_name"
    "BUS12016-hba16011-Weekday-02","20160226",2,"Washington’s Birthday"
    "Boat-F4-Sunday","20150907",1,
    """

    assert Parse.CalendarDates.parse(blob) == [
             %CalendarDates{
               service_id: "BUS12016-hba16011-Weekday-02",
               date: ~D[2016-02-26],
               added: false,
               holiday_name: "Washington’s Birthday"
             },
             %CalendarDates{
               service_id: "Boat-F4-Sunday",
               date: ~D[2015-09-07],
               added: true,
               holiday_name: ""
             }
           ]
  end
end
