defmodule State.Schedule.ParentStation do
  @moduledoc """
  Schedules at stops inside a parent station, stored again under the station,
  so that a trip's schedules anywhere in a station can be found with one match
  however many platforms the station has.

  Rebuilt from `State.Schedule` each time it loads new schedules.
  """

  use State.Server,
    indices: [:trip_id],
    recordable: State.Schedule.ParentStation.Record

  alias State.Schedule.ParentStation.Record

  @doc "Rebuilds the records from the schedules and stops currently loaded."
  @spec rebuild() :: :ok
  def rebuild, do: new_state(&build_state/0)

  @doc """
  The schedules matching any of the given matchers, which must each include a
  `:trip_id` and `:parent_station`, and can include `:stop_sequence` or
  `:position`.
  """
  @spec select_schedules([map]) :: [Model.Schedule.t()]
  def select_schedules(matchers) do
    matchers
    |> select(:trip_id)
    |> Enum.map(& &1.schedule)
  end

  @spec build_state() :: [Record.t()]
  defp build_state do
    parent_stations =
      for %{id: id, parent_station: station_id} <- State.Stop.all(),
          is_binary(station_id),
          into: %{},
          do: {id, station_id}

    # fold over the table rather than loading every schedule at once, since
    # only schedules inside stations are kept
    fn ->
      :mnesia.foldl(
        fn record, acc ->
          schedule = Model.Schedule.from_record(record)

          case Map.fetch(parent_stations, schedule.stop_id) do
            {:ok, station_id} -> [to_record(schedule, station_id) | acc]
            :error -> acc
          end
        end,
        [],
        State.Schedule
      )
    end
    |> :mnesia.async_dirty()
    |> Enum.reverse()
  end

  defp to_record(schedule, station_id) do
    %Record{
      trip_id: schedule.trip_id,
      parent_station: station_id,
      stop_sequence: schedule.stop_sequence,
      position: schedule.position,
      schedule: schedule
    }
  end
end
