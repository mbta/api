defmodule Parse.StopEventsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Parse.StopEvents
  alias Model.StopEvent

  describe "parse" do
    test "parses valid NDJSON data with multiple stop events" do
      ndjson = """
      {"id":"73885810-64-y2071-1","timestamp":1771968343,"start_date":"20260224","trip_id":"73885810","vehicle_id":"y2071","direction_id":0,"route_id":"64","start_time":"16:07:00","revenue":true,"stop_id":"2231","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      {"id":"73885810-64-y2071-2","timestamp":1771968343,"start_date":"20260224","trip_id":"73885810","vehicle_id":"y2071","direction_id":0,"route_id":"64","start_time":"16:07:00","revenue":true,"stop_id":"12232","stop_sequence":2,"arrived":1771967286,"departed":1771967333}
      {"id":"73221192-Green-E-G-10077-4","timestamp":1771950045,"start_date":"20260224","trip_id":"73221192","vehicle_id":"G-10077","direction_id":0,"route_id":"Green-E","start_time":"10:16:00","revenue":true,"stop_id":"70512","stop_sequence":4,"arrived":1771946303,"departed":1771946479}
      """

      result = parse(ndjson)

      assert length(result) == 3

      assert %StopEvent{
               id: "73885810-64-y2071-1",
               vehicle_id: "y2071",
               start_date: ~D[2026-02-24],
               trip_id: "73885810",
               direction_id: 0,
               route_id: "64",
               start_time: "16:07:00",
               revenue: :REVENUE,
               stop_id: "2231",
               stop_sequence: 1,
               arrived: %DateTime{},
               departed: %DateTime{}
             } = Enum.find(result, &(&1.id == "73885810-64-y2071-1"))

      assert %StopEvent{
               id: "73885810-64-y2071-2",
               vehicle_id: "y2071",
               start_date: ~D[2026-02-24],
               trip_id: "73885810",
               direction_id: 0,
               route_id: "64",
               start_time: "16:07:00",
               revenue: :REVENUE,
               stop_id: "12232",
               stop_sequence: 2,
               arrived: %DateTime{},
               departed: %DateTime{}
             } = Enum.find(result, &(&1.id == "73885810-64-y2071-2"))

      assert %StopEvent{
               id: "73221192-Green-E-G-10077-4",
               vehicle_id: "G-10077",
               start_date: ~D[2026-02-24],
               trip_id: "73221192",
               direction_id: 0,
               route_id: "Green-E",
               start_time: "10:16:00",
               revenue: :REVENUE,
               stop_id: "70512",
               stop_sequence: 4,
               arrived: %DateTime{},
               departed: %DateTime{}
             } = Enum.find(result, &(&1.id == "73221192-Green-E-G-10077-4"))
    end

    test "handles null departed times for last stop" do
      ndjson = """
      {"id":"test-trip-1","timestamp":1771968343,"start_date":"20260224","trip_id":"test","vehicle_id":"v1","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":null}
      """

      result = parse(ndjson)

      assert [%StopEvent{departed: nil}] = result
    end

    test "handles null arrived times for first stop" do
      ndjson = """
      {"id":"test-trip-1","timestamp":1771968343,"start_date":"20260224","trip_id":"test","vehicle_id":"v1","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":null,"departed":1771967246}
      """

      result = parse(ndjson)

      assert [%StopEvent{arrived: nil}] = result
    end

    test "handles non-revenue trips" do
      ndjson = """
      {"id":"test-trip-1","timestamp":1771968343,"start_date":"20260224","trip_id":"test","vehicle_id":"v1","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":false,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      """

      result = parse(ndjson)

      assert [%StopEvent{revenue: :NON_REVENUE}] = result
    end

    test "ignores empty lines in NDJSON" do
      ndjson = """

      {"id":"test-trip-1","timestamp":1771968343,"start_date":"20260224","trip_id":"test","vehicle_id":"v1","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}

      """

      result = parse(ndjson)

      assert length(result) == 1
    end

    test "parses stop events with optional arrived/departed fields" do
      ndjson = """
      {"id":"first-stop-1","timestamp":1771968343,"start_date":"20260224","trip_id":"arrived","vehicle_id":"v1","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop1","stop_sequence":1,"departed":1771967246}
      {"id":"last-stop-1","timestamp":1771968343,"start_date":"20260224","trip_id":"departed","vehicle_id":"v1","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486}
      {"id":"middle-stop-1","timestamp":1771968343,"start_date":"20260224","trip_id":"both-times","vehicle_id":"v2","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop2","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      """

      result = parse(ndjson)

      assert [
               %StopEvent{trip_id: "arrived", arrived: nil, departed: %DateTime{}},
               %StopEvent{trip_id: "departed", arrived: %DateTime{}, departed: nil},
               %StopEvent{trip_id: "both-times", arrived: %DateTime{}, departed: %DateTime{}}
             ] = result
    end

    test "logs and ignores lines with missing required fields" do
      ndjson = """
      {"id":"missing-stop-id-1","timestamp":1771968343,"start_date":"20260224","trip_id":"missing","vehicle_id":"v1","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      """

      log =
        capture_log(fn ->
          result = parse(ndjson)
          assert result == []
        end)

      assert log =~ "missing_fields"
    end

    test "logs and ignores lines with invalid date format" do
      ndjson = """
      {"id":"test-trip-1","timestamp":1771968343,"start_date":"invalid","trip_id":"test","vehicle_id":"v1","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      """

      log =
        capture_log(fn ->
          assert parse(ndjson) == []
        end)

      assert log =~ "invalid_date"
    end

    test "logs and ignores records with various invalid fields" do
      ndjson = """
      {"id":"invalid-revenue","timestamp":1771968343,"start_date":"20260224","trip_id":"test1","vehicle_id":"v1","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":"maybe","stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      {"id":"invalid-start-date","timestamp":1771968343,"start_date":"2026-02-24","trip_id":"test2","vehicle_id":"v2","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      {"id":"invalid-arrived-type","timestamp":1771968343,"start_date":"20260224","trip_id":"test3","vehicle_id":"v3","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":"2026-02-24T10:00:00","departed":1771967246}
      {"id":"invalid-departed-type","timestamp":1771968343,"start_date":"20260224","trip_id":"test4","vehicle_id":"v4","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":12.5}
      """

      log =
        capture_log(fn ->
          result = parse(ndjson)
          assert result == []
        end)

      assert log =~ "invalid_revenue"
      assert log =~ "invalid_date"
      assert log =~ "invalid_timestamp_type"
    end

    test "handles invalid JSON" do
      log =
        capture_log(fn ->
          assert parse("{abc\n{def}") == []
        end)

      assert log =~ "decode_error"
    end

    test "parses gzipped NDJSON data" do
      ndjson = """
      {"id":"test-trip-1","timestamp":1771968343,"start_date":"20260224","trip_id":"test","vehicle_id":"v1","direction_id":0,"route_id":"1","start_time":"10:00:00","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      """

      gzipped = :zlib.gzip(ndjson)

      result = parse(gzipped)

      assert length(result) == 1
      assert [%StopEvent{id: "test-trip-1"}] = result
    end
  end
end
