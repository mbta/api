defmodule Parse.CalendarAttributesTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Parse.CalendarAttributes

  test "parses calendar entries" do
    blob = """
    service_id,service_description,service_schedule_name,service_schedule_type,service_schedule_typicality
    BUS12019-hba19ns1-Weekday-02,Weekday schedule (no school),Weekday (no school),Weekday,1
    """

    assert CalendarAttributes.parse(blob) == [
             %CalendarAttributes{
               service_id: "BUS12019-hba19ns1-Weekday-02",
               description: "Weekday schedule (no school)",
               schedule_name: "Weekday (no school)",
               schedule_type: "Weekday",
               schedule_typicality: 1
             }
           ]
  end

  test "parses calendar entries with missing fields" do
    blob = """
    service_id,service_description,service_schedule_name,service_schedule_type,service_schedule_typicality
    BUS12019-hba19ns1-Weekday-02,,,,
    """

    assert CalendarAttributes.parse(blob) == [
             %CalendarAttributes{
               service_id: "BUS12019-hba19ns1-Weekday-02",
               description: nil,
               schedule_name: nil,
               schedule_type: nil,
               schedule_typicality: nil
             }
           ]
  end
end
