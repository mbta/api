defmodule Parse.CalendarTest do
  use ExUnit.Case, async: true
  alias Parse.Calendar
  use Timex

  test "parses calendar entries" do
    blob = """
    "service_id","monday","tuesday","wednesday","thursday","friday","saturday","sunday","start_date","end_date"
    "BUS22016-hba26ns1-Weekday-02",1,1,1,1,1,0,0,"20160418","20160422"
    "BUS12016-hbb16hl6-Saturday-02",0,0,0,0,0,1,1,"20160215","20160215"
    """

    assert Parse.Calendar.parse(blob) == [
             %Calendar{
               service_id: "BUS22016-hba26ns1-Weekday-02",
               days: [1, 2, 3, 4, 5],
               start_date: ~D[2016-04-18],
               end_date: ~D[2016-04-22]
             },
             %Calendar{
               service_id: "BUS12016-hbb16hl6-Saturday-02",
               days: [6, 7],
               start_date: ~D[2016-02-15],
               end_date: ~D[2016-02-15]
             }
           ]
  end
end
