defmodule Health.Checkers.State do
  @moduledoc """
  Health check which makes sure various State modules have data.
  """
  use Events.Server

  @apps [
    State.Schedule,
    State.Alert,
    State.ServiceByDate,
    State.StopsOnRoute,
    State.RoutesAtStop,
    State.Shape
  ]

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def current do
    GenServer.call(__MODULE__, :current)
  end

  def healthy? do
    current()
    |> Enum.all?(fn {_, count} ->
      count > 0
    end)
  end

  @impl Events.Server
  def handle_event({:new_state, app}, count, _, state) do
    new_state =
      state
      |> Keyword.put(app_name(app), count)

    {:noreply, new_state}
  end

  @impl GenServer
  def init(nil) do
    statuses =
      for app <- @apps do
        subscribe({:new_state, app})
        {app_name(app), app.size}
      end

    {:ok, statuses}
  end

  @impl GenServer
  def handle_call(:current, _from, state) do
    {:reply, state, state}
  end

  defp app_name(app) do
    app
    |> Module.split()
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end
end
