defmodule Parse.CalendarAttributesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Parse.CalendarAttributes

  test "parses calendar entries" do
    blob = """
    service_id,service_description,service_schedule_name,service_schedule_type,service_schedule_typicality,rating_start_date,rating_end_date,rating_description
    BUS12019-hba19ns1-Weekday-02,Weekday schedule (no school),Weekday (no school),Weekday,1,20181222,20190314,Winter
    """

    assert CalendarAttributes.parse(blob) == [
             %CalendarAttributes{
               service_id: "BUS12019-hba19ns1-Weekday-02",
               description: "Weekday schedule (no school)",
               schedule_name: "Weekday (no school)",
               schedule_type: "Weekday",
               schedule_typicality: 1,
               rating_start_date: ~D[2018-12-22],
               rating_end_date: ~D[2019-03-14],
               rating_description: "Winter"
             }
           ]
  end

  test "parses calendar entries with missing fields" do
    blob = """
    service_id,service_description,service_schedule_name,service_schedule_type,service_schedule_typicality,rating_start_date,rating_end_date,rating_description
    BUS12019-hba19ns1-Weekday-02,,,,,,,
    """

    assert CalendarAttributes.parse(blob) == [
             %CalendarAttributes{
               service_id: "BUS12019-hba19ns1-Weekday-02",
               description: nil,
               schedule_name: nil,
               schedule_type: nil,
               schedule_typicality: nil,
               rating_start_date: nil,
               rating_end_date: nil,
               rating_description: nil
             }
           ]
  end
end
