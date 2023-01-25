defmodule State.Service do
  @moduledoc """

  Service represents the days of the week, as well as extra days, that a trip
  is valid.

  """
  use State.Server,
    indices: [:id],
    recordable: Model.Service

  alias Events.Gather
  alias Model.Service

  use Timex

  def by_id(id) do
    case super(id) do
      [] -> nil
      [service] -> service
    end
  end

  def by_route_ids(route_ids) do
    route_ids
    |> State.Trip.by_route_ids()
    |> MapSet.new(& &1.service_id)
    |> MapSet.to_list()
    |> by_ids
  end

  def by_route_id(route_id) do
    by_route_ids([route_id])
  end

  @doc """
  Returns all Services that are valid today or any date in the future.
  """
  def valid_in_future do
    now = Parse.Time.service_date()
    Enum.filter(all(), &Service.valid_after?(&1, now))
  end

  @doc """
  Returns all Services that are valid on the given date.
  """
  def valid_for_date(%Date{} = date) do
    Enum.filter(all(), &Service.valid_for_date?(&1, date))
  end

  @impl Events.Server
  def handle_event(event, value, _, state) do
    state = %{state | data: Gather.update(state.data, event, value)}
    {:noreply, state, :hibernate}
  end

  @impl GenServer
  def init(_) do
    _ = super(nil)

    subscriptions = [
      {:fetch, "calendar.txt"},
      {:fetch, "calendar_attributes.txt"},
      {:fetch, "calendar_dates.txt"}
    ]

    for sub <- subscriptions, do: subscribe(sub)

    state = %{data: Gather.new(subscriptions, &do_gather/1), last_updated: nil}
    {:ok, state}
  end

  @impl State.Server
  def handle_new_state({
        calendar,
        calendar_attributes,
        calendar_dates
      }) do
    service_ids =
      [
        Enum.map(calendar, &Map.get(&1, :service_id)),
        Enum.map(calendar_attributes, &Map.get(&1, :service_id)),
        Enum.map(calendar_dates, &Map.get(&1, :service_id))
      ]
      |> Enum.concat()
      |> Enum.uniq()

    for service_id <- service_ids do
      service = Enum.find(calendar, &Kernel.==(Map.get(&1, :service_id), service_id))
      added = dates(calendar_dates, service_id, true)
      removed = dates(calendar_dates, service_id, false)
      # if we have a service, then use that for the dates
      # if we don't, then use first date from calendar
      {start_date, end_date, valid_days} =
        case service do
          nil -> {List.first(added), List.last(added), []}
          _ -> {service.start_date, service.end_date, service.days}
        end

      attributes =
        Enum.find(
          calendar_attributes,
          %Parse.CalendarAttributes{},
          fn s -> s.service_id == service_id end
        )

      %Service{
        id: service_id,
        start_date: start_date,
        end_date: end_date,
        valid_days: valid_days,
        description: attributes.description,
        schedule_name: attributes.schedule_name,
        schedule_type: attributes.schedule_type,
        schedule_typicality: attributes.schedule_typicality || 0,
        rating_start_date: attributes.rating_start_date,
        rating_end_date: attributes.rating_end_date,
        rating_description: attributes.rating_description,
        added_dates: added,
        added_dates_notes: holiday_names(calendar_dates, added),
        removed_dates: removed,
        removed_dates_notes: holiday_names(calendar_dates, removed)
      }
    end
    |> super()
  end

  def handle_new_state(other), do: super(other)

  @impl State.Server
  def post_commit_hook do
    State.ServiceByDate.update!()
  end

  defp dates(calendar_dates, service_id, added) do
    calendar_dates
    |> Stream.filter(&(&1.service_id == service_id and &1.added == added))
    |> Enum.map(& &1.date)
    |> Enum.sort_by(&Date.to_iso8601/1)
  end

  defp holiday_names(calendar_dates, dates) do
    Enum.map(dates, &holiday_name(calendar_dates, &1))
  end

  defp holiday_name(calendar_dates, date) do
    cd =
      calendar_dates
      |> Stream.filter(&(&1.date == date and &1.holiday_name != ""))
      |> Enum.take(1)

    case cd do
      [%Parse.CalendarDates{holiday_name: holiday_name}] -> holiday_name
      _ -> nil
    end
  end

  defp do_gather(%{
         {:fetch, "calendar.txt"} => calendar_blob,
         {:fetch, "calendar_attributes.txt"} => attributes_blob,
         {:fetch, "calendar_dates.txt"} => dates_blob
       }) do
    [calendar, calendar_attributes, calendar_dates] =
      [
        Task.async(Parse.Calendar, :parse, [calendar_blob]),
        Task.async(Parse.CalendarAttributes, :parse, [attributes_blob]),
        Task.async(Parse.CalendarDates, :parse, [dates_blob])
      ]
      |> Enum.map(&Task.await/1)

    handle_new_state({
      calendar,
      calendar_attributes,
      calendar_dates
    })
  end
end
