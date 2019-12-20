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
      worker(State.RoutesPatternsAtStop, []),
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
  @spec all([map], [option] | map) ::
          [map] | {[map], State.Pagination.Offsets.t()} | {:error, atom}
  def all(results, opts \\ [])
  def all([], _), do: []

  def all(results, []) do
    results
  end

  def all(results, opts) when is_list(results) do
    opts = Map.new(opts)

    case State.order_by(results, opts) do
      {:error, _} = error ->
        error

      new_results ->
        State.Pagination.paginate(new_results, opts)
    end
  end

  @doc false
  @spec order_by([map], [sort_option] | map) :: [map] | {:error, atom}
  def order_by(results, opts \\ [])
  def order_by([], _), do: []

  def order_by(results, opts) do
    opts = Map.new(opts)

    case opts do
      %{order_by: keys} ->
        keys =
          keys
          |> List.wrap()
          |> Enum.reverse()

        order_by_keys(results, keys, opts)

      _ ->
        # order_by not present
        results
    end
  end

  defp order_by_keys(results, [{:distance, dir} | keys], %{latitude: _, longitude: _} = opts) do
    results
    |> do_order_by({:distance, get_latlng(opts)}, dir)
    |> order_by_keys(keys, opts)
  end

  defp order_by_keys([result | _] = results, [{:time, dir} | keys], opts) do
    if valid_order_by_key?(:arrival_time, result) or valid_order_by_key?(:departure_time, result) do
      results
      |> do_order_by(:time, dir)
      |> order_by_keys(keys, opts)
    else
      {:error, :invalid_order_by}
    end
  end

  defp order_by_keys([result | _] = results, [{key, dir} | keys], opts) do
    if valid_order_by_key?(key, result) do
      results
      |> do_order_by(key, dir)
      |> order_by_keys(keys, opts)
    else
      {:error, :invalid_order_by}
    end
  end

  defp order_by_keys(results, [], _opts) do
    results
  end

  defp order_by_keys(_results, _keys, _opts) do
    {:error, :invalid_order_by}
  end

  defp valid_order_by_key?(:distance, _) do
    false
  end

  defp valid_order_by_key?(key, result) do
    Map.has_key?(result, key)
  end

  defp do_order_by(results, key, :asc) do
    sort_fn = mapper_fn(key)
    Enum.sort_by(results, sort_fn, &<=/2)
  end

  defp do_order_by(results, key, :desc) do
    sort_fn = mapper_fn(key)
    Enum.sort_by(results, sort_fn, &>=/2)
  end

  defp mapper_fn({:distance, position}) do
    &distance({&1.latitude, &1.longitude}, position)
  end

  defp mapper_fn(:time) do
    &time/1
  end

  defp mapper_fn(key) do
    fn
      %{^key => %DateTime{} = dt} ->
        {:date_time, DateTime.to_unix(dt)}

      %{^key => value} ->
        value
    end
  end

  defp time(%{arrival_time: nil, departure_time: nil}) do
    nil
  end

  defp time(%{arrival_time: nil, departure_time: %DateTime{} = time}) do
    {:date_time, DateTime.to_unix(time)}
  end

  defp time(%{arrival_time: %DateTime{} = time}) do
    {:date_time, DateTime.to_unix(time)}
  end

  defp time(%{arrival_time: nil, departure_time: time}) do
    {:seconds, time}
  end

  defp time(%{arrival_time: time}) do
    {:seconds, time}
  end

  defp fetch_float(opts_map, key) do
    case opts_map do
      %{^key => val} ->
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
