defmodule ApiWeb.StatusView do
  use ApiWeb.Web, :api_view

  attributes([
    :feed,
    :alert,
    :facility,
    :prediction,
    :route,
    :route_pattern,
    :schedule,
    :service,
    :shape,
    :stop,
    :trip,
    :vehicle
  ])

  def feed(data, _), do: data.feed

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

  def route_pattern(data, _) do
    %{last_updated: data.timestamps.route_pattern}
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
