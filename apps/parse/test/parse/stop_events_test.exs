defmodule Parse.StopEventsTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  import Parse.StopEvents
  alias Model.StopEvent

  @valid_stop_event_json """
  {"id":"test-trip-1","timestamp":1771968343,"start_date":"20260224","trip_id":"test","vehicle_id":"v1","direction_id":0,"route_id":"1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
  """

  @multiple_stop_events """
  {"id":"73885810-64-y2071-1","timestamp":1771968343,"start_date":"20260224","trip_id":"73885810","vehicle_id":"y2071","direction_id":0,"route_id":"64","revenue":true,"stop_id":"2231","stop_sequence":1,"arrived":1771966486,"departed":null}
  {"id":"73885810-64-y2071-2","timestamp":1771968343,"start_date":"20260224","trip_id":"73885810","vehicle_id":"y2071","direction_id":0,"route_id":"64","revenue":true,"stop_id":"12232","stop_sequence":2,"arrived":null,"departed":1771967333}
  {"id":"73221192-Green-E-G-10077-4","timestamp":1771950045,"start_date":"20260224","trip_id":"73221192","vehicle_id":"G-10077","direction_id":0,"route_id":"Green-E","revenue":true,"stop_id":"70512","stop_sequence":4,"arrived":1771946303,"departed":1771946479}
  """

  describe "parse" do
    test "parses valid NDJSON data with multiple stop events" do
      result =
        @multiple_stop_events |> parse() |> Enum.sort_by(& &1.id)

      expectation = [
        # both arrival and departure
        %StopEvent{
          id: "73221192-Green-E-G-10077-4",
          vehicle_id: "G-10077",
          start_date: ~D[2026-02-24],
          trip_id: "73221192",
          direction_id: 0,
          route_id: "Green-E",
          revenue: :REVENUE,
          stop_id: "70512",
          stop_sequence: 4,
          arrived: DateTime.from_naive!(~N[2026-02-24T10:18:23], "America/New_York"),
          departed: DateTime.from_naive!(~N[2026-02-24T10:21:19], "America/New_York")
        },
        # arrival only
        %StopEvent{
          id: "73885810-64-y2071-1",
          vehicle_id: "y2071",
          start_date: ~D[2026-02-24],
          trip_id: "73885810",
          direction_id: 0,
          route_id: "64",
          revenue: :REVENUE,
          stop_id: "2231",
          stop_sequence: 1,
          arrived: DateTime.from_naive!(~N[2026-02-24T15:54:46], "America/New_York"),
          departed: nil
        },
        # departure only
        %StopEvent{
          id: "73885810-64-y2071-2",
          vehicle_id: "y2071",
          start_date: ~D[2026-02-24],
          trip_id: "73885810",
          direction_id: 0,
          route_id: "64",
          revenue: :REVENUE,
          stop_id: "12232",
          stop_sequence: 2,
          arrived: nil,
          departed: DateTime.from_naive!(~N[2026-02-24T16:08:53], "America/New_York")
        }
      ]

      assert expectation == result
    end

    test "handles non-revenue trips" do
      ndjson = """
      {"id":"test-trip-1","timestamp":1771968343,"start_date":"20260224","trip_id":"test","vehicle_id":"v1","direction_id":0,"route_id":"1","revenue":false,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      """

      result = parse(ndjson)

      assert [%StopEvent{revenue: :NON_REVENUE}] = result
    end

    test "ignores empty lines in NDJSON" do
      ndjson = "\n" <> @valid_stop_event_json <> "\n"

      result = parse(ndjson)

      assert length(result) == 1
    end

    test "logs and ignores lines with missing required fields" do
      ndjson = """
      {"id":"missing-stop-id-1","timestamp":1771968343,"start_date":"20260224","trip_id":"missing","vehicle_id":"v1","direction_id":0,"route_id":"1","revenue":true,"stop_sequence":1,"arrived":1771966486,"departed":1771967246}
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
      {"id":"test-trip-1","timestamp":1771968343,"start_date":"invalid","trip_id":"test","vehicle_id":"v1","direction_id":0,"route_id":"1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      """

      log =
        capture_log(fn ->
          assert parse(ndjson) == []
        end)

      assert log =~ "invalid_date"
    end

    test "logs and ignores records with various invalid fields" do
      ndjson = """
      {"id":"invalid-revenue","timestamp":1771968343,"start_date":"20260224","trip_id":"test1","vehicle_id":"v1","direction_id":0,"route_id":"1","revenue":"maybe","stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      {"id":"invalid-start-date","timestamp":1771968343,"start_date":"2026-02-24","trip_id":"test2","vehicle_id":"v2","direction_id":0,"route_id":"1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":1771967246}
      {"id":"invalid-arrived-type","timestamp":1771968343,"start_date":"20260224","trip_id":"test3","vehicle_id":"v3","direction_id":0,"route_id":"1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":"2026-02-24T10:00:00","departed":1771967246}
      {"id":"invalid-departed-type","timestamp":1771968343,"start_date":"20260224","trip_id":"test4","vehicle_id":"v4","direction_id":0,"route_id":"1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":12.5}
      {"id":"invalid-departed-value","timestamp":1771968343,"start_date":"20260224","trip_id":"test4","vehicle_id":"v4","direction_id":0,"route_id":"1","revenue":true,"stop_id":"stop1","stop_sequence":1,"arrived":1771966486,"departed":12345678901234567890}
      """

      log =
        capture_log(fn ->
          result = parse(ndjson)
          assert result == []
        end)

      assert log =~ "invalid_revenue"
      assert log =~ "invalid_date"
      assert log =~ "invalid_timestamp_type"
      assert log =~ "invalid_unix_timestamp"
    end

    test "handles invalid JSON" do
      log =
        capture_log(fn ->
          assert parse("{abc\n{def}") == []
        end)

      assert log =~ "decode_error"
    end

    test "parses gzipped NDJSON data" do
      gzipped = :zlib.gzip(@valid_stop_event_json)

      result = parse(gzipped)

      assert length(result) == 1
      assert [%StopEvent{id: "test-trip-1"}] = result
    end
  end
end
