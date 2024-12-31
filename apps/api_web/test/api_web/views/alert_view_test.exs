defmodule ApiWeb.AlertViewTest do
  use ApiWeb.ConnCase

  import ApiWeb.AlertView
  import ApiWeb.ApiControllerHelpers, only: [split_include: 2]

  @alert %Model.Alert{
    id: "id",
    effect: "effect",
    cause: "cause",
    url: "url",
    header: "header",
    short_header: "short header",
    banner: "banner",
    description: "description",
    created_at: Timex.now(),
    updated_at: Timex.shift(Timex.now(), minutes: 1),
    severity: "severity",
    active_period: [{Timex.now(), nil}],
    informed_entity: [%{route_type: 0, route: "1"}],
    service_effect: "service effect",
    timeframe: "timeframe",
    lifecycle: "lifecycle",
    image: "image",
    image_alternative_text: "image alternative text",
    duration_certainty: "KNOWN"
  }

  test "can do a basic rendering (does not include relationships)", %{conn: conn} do
    rendered = render("index.json-api", data: @alert, conn: conn)["data"]
    assert rendered["type"] == "alert"
    assert rendered["id"] == "id"

    assert rendered["attributes"] == %{
             "effect" => @alert.effect,
             "cause" => @alert.cause,
             "url" => @alert.url,
             "header" => @alert.header,
             "short_header" => @alert.short_header,
             "banner" => @alert.banner,
             "description" => @alert.description,
             "created_at" => @alert.created_at,
             "updated_at" => @alert.updated_at,
             "severity" => @alert.severity,
             "image" => @alert.image,
             "image_alternative_text" => @alert.image_alternative_text,
             "active_period" => [
               %{
                 "start" => @alert.active_period |> List.first() |> elem(0),
                 "end" => @alert.active_period |> List.first() |> elem(1)
               }
             ],
             "informed_entity" => @alert.informed_entity,
             "service_effect" => @alert.service_effect,
             "timeframe" => @alert.timeframe,
             "lifecycle" => @alert.lifecycle,
             "duration_certainty" => @alert.duration_certainty
           }

    refute rendered["relationships"]
  end

  test "combines informed entity relationships", %{conn: conn} do
    State.Route.new_state([%Model.Route{id: "1"}, %Model.Route{id: "2"}])
    State.Stop.new_state([%Model.Stop{id: "2"}])
    State.Trip.new_state([%Model.Trip{id: "3"}])
    State.Facility.new_state([%Model.Facility{id: "6"}])

    entities = [
      # ignored
      %{route_type: 0},
      %{route: "1", stop: "2", direction_id: 1},
      %{route: "2", trip: "3"},
      %{facility: "6"}
    ]

    alert = %{@alert | informed_entity: entities}
    conn = split_include(%{conn | params: %{"include" => "routes,stops,trips,facilities"}}, [])

    rendered = render("index.json-api", data: alert, conn: conn)["data"]

    assert rendered["relationships"] == %{
             "routes" => %{
               "data" => [%{"type" => "route", "id" => "1"}, %{"type" => "route", "id" => "2"}]
             },
             "stops" => %{"data" => [%{"type" => "stop", "id" => "2"}]},
             "trips" => %{"data" => [%{"type" => "trip", "id" => "3"}]},
             "facilities" => %{"data" => [%{"type" => "facility", "id" => "6"}]}
           }
  end
end
