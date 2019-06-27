defmodule State do
  @moduledoc """
  Maintains the current state of the MBTA system: routes, schedules, vehicle locations, predictions, etc. It also allows
  for querying of that state to answer questions from clients.
  """

  use Application

  @type sort_option :: {:order_by, {atom, :asc | :desc}}
  @type option :: sort_option | State.Pagination.pagination_option()

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(State.Metadata, []),
      worker(State.Service, []),
      supervisor(State.Stop, []),
      worker(State.Vehicle, []),
      worker(State.Alert, []),
      worker(State.Facility, []),
      worker(State.Facility.Property, []),
      worker(State.Facility.Parking, []),
      worker(State.Route, []),
      worker(State.RoutePattern, []),
      worker(State.Line, []),
      worker(State.Trip, []),
      worker(State.Trip.Added, []),
      worker(State.Schedule, []),
      worker(State.Prediction, []),
      worker(State.StopsOnRoute, []),
      worker(State.RoutesAtStop, []),
      worker(State.ServiceByDate, []),
      worker(State.Shape, []),
      worker(State.Feed, []),
      worker(State.Transfer, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: State.Application, max_restarts: length(children)]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Fetches a configuration value and raises if missing.

  ## Examples

      iex> State.config(:routes, :hidden_ids_exact)
      [...]
  """
  def config(root_key, sub_key) do
    root_key
    |> config()
    |> Keyword.fetch!(sub_key)
  end

  def config(root_key) do
    Application.fetch_env!(:state, root_key)
  end

  @doc """
  Enumerates a result-set according to a list of options.

    * `results` - the list of results
    * `opts` - the Keyword list of options:
      * `:order_by` - a 2-tuple containg the field to order by
        and direction, for example: `{:id, :asc}`, `{:name, :desc}`
      * `:limit` - the number of results to be returned
      * `:offset` - the offset of results to beging selection from

  When `:limit` is provided, the function gives a tuple of the paginated list
  and a struct of pagination offset values for the next, previous, first and
  last pages.

  When both sorting and pagination options are used, sorting will happen before
  any pagination operation.

  ## Examples
      iex(1)> items = [%{id: 1}, %{id: 2}, %{id: 3}, %{id: 4}, %{id: 5}]
      iex(2)> State.all(items, limit: 2, offset: 2)
      {[%{id: 3}, %{id: 4}], %State.Pagination.Offsets{
        prev: 0,
        next: 4,
        first: 0,
        last: 4
      }}

      iex> State.all([%{id: 3}, %{id: 1}, %{id: 2}], order_by: {:id, :asc})
      [%{id: 1}, %{id: 2}, %{id: 3}]

      iex> State.all([%{id: 3}, %{id: 1}, %{id: 2}], order_by: [{:id, :desc}])
      [%{id: 3}, %{id: 2}, %{id: 1}]

      iex> State.all([%{id: 3}, %{id: 1}, %{id: 2}], order_by: [{:invalid, :asc}])
      {:error, :invalid_order_by}

  """
  @spec all([map], [option]) :: [map] | {[map], State.Pagination.Offsets.t()} | {:error, atom}
  def all(results, opts \\ [])
  def all([], _), do: []

  def all(results, opts) when is_list(results) do
    case State.order_by(results, opts) do
      {:error, _} = error ->
        error

      new_results ->
        State.Pagination.paginate(new_results, opts)
    end
  end

  @doc false
  @spec order_by([map], [sort_option]) :: [map] | {:error, atom}
  def order_by(results, opts \\ [])
  def order_by([], _), do: []

  def order_by(results, opts) do
    with {:ok, keys} <- Keyword.fetch(opts, :order_by) do
      keys =
        keys
        |> List.wrap()
        |> Enum.reverse()

      order_by_keys(results, keys, opts)
    else
      # order_by not present
      _ ->
        results
    end
  end

  defp order_by_keys([result | _] = results, [{key, dir} | keys], opts) do
    opts_map = Enum.into(opts, %{})

    cond do
      key == :distance and Map.has_key?(opts_map, :latitude) and
          Map.has_key?(opts_map, :longitude) ->
        {lat, lng} = get_latlng(opts)

        results
        |> sort_by_distance(lat, lng, dir)
        |> order_by_keys(keys, opts)

      key == :time and
          (valid_order_by_key?(:arrival_time, result) or
             valid_order_by_key?(:departure_time, result)) ->
        results
        |> sort_by_time(dir)
        |> order_by_keys(keys, opts)

      valid_order_by_key?(key, result) ->
        results
        |> do_order_by(key, dir)
        |> order_by_keys(keys, opts)

      true ->
        {:error, :invalid_order_by}
    end
  end

  defp order_by_keys(results, [], _opts) do
    results
  end

  defp valid_order_by_key?(:distance, _) do
    false
  end

  defp valid_order_by_key?(key, result) do
    case result do
      %{^key => _} -> true
      _ -> false
    end
  end

  defp do_order_by(results, :distance, _) do
    results
  end

  defp do_order_by(results, key, :asc) do
    Enum.sort_by(results, &mapper_fn(&1, key), &<=/2)
  end

  defp do_order_by(results, key, :desc) do
    Enum.sort_by(results, &mapper_fn(&1, key), &>=/2)
  end

  defp mapper_fn(result, key) do
    case Map.get(result, key) do
      %DateTime{} = dt -> {:date_time, DateTime.to_unix(dt)}
      other -> other
    end
  end

  def sort_by_distance(results, lat, lng, :asc) do
    Enum.sort_by(results, &distance({&1.latitude, &1.longitude}, {lat, lng}), &<=/2)
  end

  def sort_by_distance(results, lat, lng, :desc) do
    Enum.sort_by(results, &distance({&1.latitude, &1.longitude}, {lat, lng}), &>=/2)
  end

  defp time(%{arrival_time: nil, departure_time: time}) do
    time
  end

  defp time(%{arrival_time: time}) do
    time
  end

  def sort_by_time(results, :asc) do
    Enum.sort_by(results, &time/1, &<=/2)
  end

  def sort_by_time(results, :desc) do
    Enum.sort_by(results, &time/1, &>=/2)
  end

  defp fetch_float(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, val} ->
        case Float.parse(val) do
          {parsed_value, ""} ->
            parsed_value

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def distance({lat1, lng1}, {lat2, lng2}) do
    :math.sqrt(:math.pow(lat1 - lat2, 2) + :math.pow(lng1 - lng2, 2))
  end

  def get_latlng(opts) do
    {fetch_float(opts, :latitude), fetch_float(opts, :longitude)}
  end
end
