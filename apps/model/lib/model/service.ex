defmodule Model.Service do
  @moduledoc """
  Service represents a set of dates on which trips run.
  """
  use Recordable,
    id: nil,
    start_date: ~D[1970-01-01],
    end_date: ~D[9999-12-31],
    valid_days: [],
    description: nil,
    schedule_name: nil,
    schedule_type: nil,
    schedule_typicality: 0,
    added_dates: [],
    added_dates_notes: [],
    removed_dates: [],
    removed_dates_notes: []

  @type id :: String.t()
  @type t :: %__MODULE__{
          id: id,
          start_date: Date.t(),
          end_date: Date.t(),
          valid_days: [Timex.Types.weekday()],
          description: String.t(),
          schedule_name: String.t(),
          schedule_type: String.t(),
          schedule_typicality: 0..5,
          added_dates: [Date.t()],
          added_dates_notes: [String.t()],
          removed_dates: [Date.t()],
          removed_dates_notes: [String.t()]
        }

  @doc """
  Returns the earliest date which is valid for this service.
  """
  def start_date(%__MODULE__{} = service) do
    # we don't need to take removed dates into account because they're
    # already not valid.
    [service.start_date | service.added_dates]
    |> Enum.min_by(&Date.to_erl/1)
  end

  @doc """
  Returns the latest date which is valid for this service.
  """
  def end_date(%__MODULE__{} = service) do
    # we don't need to take removed dates into account because they're
    # already not valid.
    [service.end_date | service.added_dates]
    |> Enum.max_by(&Date.to_erl/1)
  end

  @doc """
  Returns true if this service is valid on or after the given date.

  iex> service = %Service{
  ...>   start_date: ~D[2018-03-01],
  ...>   end_date: ~D[2018-03-30],
  ...>   valid_days: [1, 2, 3, 4],
  ...>   added_dates: [~D[2018-04-01]],
  ...>   removed_dates: [~D[2018-03-15]]
  ...> }
  iex> valid_after?(service, ~D[2018-02-01])
  true
  iex> valid_after?(service, ~D[2018-03-01])
  true
  iex> valid_after?(service, ~D[2018-04-01])
  true
  iex> valid_after?(service, ~D[2018-04-02])
  false
  """

  @spec valid_after?(t, Date.t()) :: boolean
  def valid_after?(%__MODULE__{end_date: end_date, added_dates: added_dates}, %Date{} = date) do
    Date.compare(end_date, date) != :lt or
      Enum.any?(added_dates, &(Date.compare(&1, date) != :lt))
  end

  @doc """
  Returns true if this service is valid on the given date.

  iex> service = %Service{
  ...>   start_date: ~D[2018-03-01],
  ...>   end_date: ~D[2018-03-30],
  ...>   valid_days: [1, 2, 3, 4],
  ...>   added_dates: [~D[2018-04-01]],
  ...>   removed_dates: [~D[2018-03-15]]
  ...> }
  iex> valid_for_date?(service, ~D[2018-03-01])
  true
  iex> valid_for_date?(service, ~D[2018-03-29])
  true
  iex> valid_for_date?(service, ~D[2018-04-01])
  true
  iex> valid_for_date?(service, ~D[2018-02-28])
  false
  iex> valid_for_date?(service, ~D[2018-03-15])
  false
  iex> valid_for_date?(service, ~D[2018-04-02])
  false
  """
  @spec valid_for_date?(t, Date.t()) :: boolean
  def valid_for_date?(
        %__MODULE__{
          start_date: start_date,
          end_date: end_date,
          valid_days: valid_days,
          added_dates: added_dates,
          removed_dates: removed_dates
        },
        %Date{} = date
      ) do
    not dates_include?(date, removed_dates) &&
      (dates_include?(date, added_dates) ||
         (between_or_equal?(date, start_date, end_date) && valid_weekday?(date, valid_days)))
  end

  @spec valid_weekday?(Date.t(), [Timex.Types.weekday()]) :: boolean
  defp valid_weekday?(date, valid_days) do
    weekday = Timex.weekday(date)

    valid_days
    |> Enum.any?(&(&1 == weekday))
  end

  @spec dates_include?(Date.t(), [Date.t()]) :: boolean
  defp dates_include?(date, date_enum) do
    date in date_enum
  end

  defp between_or_equal?(date, _, date), do: true
  defp between_or_equal?(date, date, _), do: true

  defp between_or_equal?(date, start_date, end_date) do
    Date.compare(date, start_date) != :lt and Date.compare(date, end_date) != :gt
  end
end
