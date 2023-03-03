defmodule ApiWeb.SentryEventFilter do
  @moduledoc """
    Provides a filter for exceptions coming from 404 errors
  """
  @behaviour Sentry.EventFilter

  def exclude_exception?(%Phoenix.Router.NoRouteError{}, :plug), do: true

  def exclude_exception?(error = %Sentry.CrashError{}, :logger),
    do: String.contains?(error.message, "{{{%Phoenix.Router.NoRouteError")

  def exclude_exception?(_exception, _source), do: false
end
