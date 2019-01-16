defmodule ApiWeb.StatusView do
  use ApiWeb.Web, :api_view

  attributes([
    :feed_version,
    :alert,
    :facility,
    :prediction,
    :route,
    :schedule,
    :service,
    :shape,
    :stop,
    :trip,
    :vehicle
  ])

  def feed_version(data, _), do: data.feed_version

  def alert(data, _) do
    %{last_updated: data.timestamps.alert}
  end

  def facility(data, _) do
    %{last_updated: data.timestamps.facility}
  end

  def prediction(data, _) do
    %{last_updated: data.timestamps.prediction}
  end

  def route(data, _) do
    %{last_updated: data.timestamps.route}
  end

  def schedule(data, _) do
    %{last_updated: data.timestamps.schedule}
  end

  def service(data, _) do
    %{last_updated: data.timestamps.service}
  end

  def shape(data, _) do
    %{last_updated: data.timestamps.shape}
  end

  def stop(data, _) do
    %{last_updated: data.timestamps.stop}
  end

  def trip(data, _) do
    %{last_updated: data.timestamps.trip}
  end

  def vehicle(data, _) do
    %{last_updated: data.timestamps.vehicle}
  end
end
