defmodule ApiWeb.SentryEventFilter do
  @moduledoc """
    Provides a filter for exceptions coming from 404 errors
  """

  # Sentry allows this callback to both modify events before they get sent,
  # and filter events to prevent them from being sent at all.
  # We only do the latter. Returning false prevents sending.
  @spec filter_event(Sentry.Event.t()) :: Sentry.Event.t() | false
  def filter_event(%Sentry.Event{
        source: :plug,
        original_exception: %Phoenix.Router.NoRouteError{}
      }) do
    false
  end

  def filter_event(%Sentry.Event{message: %Sentry.Interfaces.Message{}} = event) do
    if String.contains?(event.message.formatted, "{{{%Phoenix.Router.NoRouteError"),
      do: false,
      else: event
  end

  def filter_event(event), do: event
end
