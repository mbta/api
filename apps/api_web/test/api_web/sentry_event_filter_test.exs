defmodule ApiWeb.SentryEventFilterTest do
  use ApiWeb.ConnCase, async: true

  describe "filter_event/1" do
    setup do
      Sentry.Test.start_collecting_sentry_reports()
    end

    test "filters out `NoRouteError`s rescued by plugs", %{conn: conn} do
      conn = get(conn, "/a_nonexistent_route")
      assert response(conn, 404)

      assert [] = Sentry.Test.pop_sentry_reports()
    end

    test "filters out `NoRouteError`s surfaced as messages via crashes" do
      Sentry.capture_message("Something something {{{%Phoenix.Router.NoRouteError}}}")
      assert [] = Sentry.Test.pop_sentry_reports()

      Sentry.capture_message("Something something {{{%SomeOtherError}}}")
      assert [%Sentry.Event{} = err] = Sentry.Test.pop_sentry_reports()
      assert err.message.formatted =~ "SomeOtherError"
    end

    test "does not filter out other exceptions" do
      err = RuntimeError.exception("An error other than NoRouteError")

      Sentry.capture_exception(err)

      assert [%Sentry.Event{} = event] = Sentry.Test.pop_sentry_reports()
      assert ^err = event.original_exception
    end
  end
end
