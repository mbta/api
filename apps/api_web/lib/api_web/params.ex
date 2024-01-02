defmodule ApiWeb.Params do
  @moduledoc """
  Parses request params into domain datastructures.
  """

  ## Defaults
  @default_params ~w(include sort page filter fields api_key)

  @doc """
  Returns a Keyword list of options from JSONAPI query params.

  Supported options:

    * `:offset` - a `"page"` key with a map containing `"offset"`
      Resulting options include `:offset`.
    * `:limit` - a `"page"` key with a map containing `"limit"`
      Resulting options include `:limit`.
    * `:order_by` - a `"sort"` key containg a field to sort by. The key may
      be optionally prefixed with a `-`, such as "-name" for descending order,
      otherwise ascending order is assumed.
      Resulting options include an `:order_by`, for example `{:id, :asc}`.

  ## Examples

      iex> ApiWeb.Params.filter_opts(%{"page" => %{"offset" => 0}}, [:offset], build_conn())
      %{offset: 0}

      iex> ApiWeb.Params.filter_opts(%{"page" => %{"limit" => 10}}, [:limit], build_conn())
      %{limit: 10}

      iex> ApiWeb.Params.filter_opts(%{"sort" => "name"}, [:order_by], build_conn())
      %{order_by: [{:name, :asc}]}

      iex> ApiWeb.Params.filter_opts(%{"sort" => "-name,value"}, [:order_by], build_conn())
      %{order_by: [{:name, :desc}, {:value, :asc}]}

      iex> ApiWeb.Params.filter_opts(%{"sort" => "-name"}, [:order_by], build_conn(), order_by: [name: :asc])
      %{order_by: [name: :desc]}
  """
  def filter_opts(params, options, conn, acc \\ %{}) do
    Enum.reduce(options, Map.new(acc), fn opt, acc ->
      filter_opt(opt, params, conn, acc)
    end)
  end

  defp filter_opt(:offset, %{"page" => %{"offset" => offset}}, _conn, acc) do
    case parse_int(offset) do
      {:ok, offset} when offset >= 0 -> Map.put(acc, :offset, offset)
      _ -> acc
    end
  end

  defp filter_opt(:offset, _params, _conn, acc), do: acc

  defp filter_opt(:limit, %{"page" => %{"limit" => limit}}, _conn, acc) do
    case parse_int(limit) do
      {:ok, limit} when limit > 0 ->
        Map.put(acc, :limit, limit)

      _ ->
        acc
    end
  end

  defp filter_opt(:limit, _params, _conn, acc), do: acc

  defp filter_opt(:distance, %{"filter" => %{"latitude" => lat, "longitude" => lng}}, _conn, acc),
    do: Map.merge(acc, %{latitude: lat, longitude: lng})

  defp filter_opt(:distance, %{"filter" => %{"latitude" => lat}, "longitude" => lng}, _conn, acc),
    do: Map.merge(acc, %{latitude: lat, longitude: lng})

  defp filter_opt(:distance, %{"filter" => %{"longitude" => lng}, "latitude" => lat}, _conn, acc),
    do: Map.merge(acc, %{latitude: lat, longitude: lng})

  defp filter_opt(:distance, %{"longitude" => lng, "latitude" => lat}, _conn, acc),
    do: Map.merge(acc, %{latitude: lat, longitude: lng})

  defp filter_opt(:distance, _params, _conn, acc), do: acc

  defp filter_opt(:order_by, %{"sort" => fields}, conn, acc) do
    order_by =
      for field <- split_on_comma(fields) do
        case field do
          "-" <> desc_field ->
            {String.to_existing_atom(desc_field), :desc}

          asc_field ->
            {String.to_existing_atom(asc_field), :asc}
        end
      end

    Map.put(acc, :order_by, order_by)
  rescue
    ArgumentError ->
      if conn.assigns.api_version >= "2019-07-01" do
        Map.put(acc, :order_by, [{:invalid, :asc}])
      else
        acc
      end
  end

  defp filter_opt(:order_by, _params, _conn, acc), do: acc

  @doc """
  Converts comma delimited strings into integer values

  ## Examples

      iex> ApiWeb.Params.integer_values("1,2,3")
      [1, 2, 3]
      iex> ApiWeb.Params.integer_values("1,not_number,1")
      [1]
  """
  def integer_values(""), do: []

  def integer_values(str) do
    str
    |> String.split(",")
    |> Stream.map(&int(&1))
    |> Stream.filter(& &1)
    |> Enum.uniq()
  end

  @doc """
  Fetches and casts latitude, longitude, and optional radius from params.

  ## Examples

      iex> ApiWeb.Params.fetch_coords(%{"latitude" => "1.0", "longitude" => "-2.0"})
      {:ok, {1.0, -2.0, 0.01}}

      iex> ApiWeb.Params.fetch_coords(%{"latitude" => "1.0", "longitude" => "-2.0", "radius" => "5"})
      {:ok, {1.0, -2.0, 5.0}}

      iex> ApiWeb.Params.fetch_coords(%{"latitude" => "1.0", "longitude" => "nope"})
      :error

      iex> ApiWeb.Params.fetch_coords(%{})
      :error
  """
  def fetch_coords(%{"latitude" => lat, "longitude" => long} = params) do
    with {parsed_lat, ""} <- Float.parse(lat),
         {parsed_long, ""} <- Float.parse(long),
         {radius, ""} <- Float.parse(Map.get(params, "radius", "0.01")) do
      {:ok, {parsed_lat, parsed_long, radius}}
    else
      _ -> :error
    end
  end

  def fetch_coords(%{}), do: :error

  @doc """
  Splits a param key by comma into a list of values.
  """
  @spec split_on_comma(%{any => String.t()}, any) :: [String.t()]
  def split_on_comma(params, name) do
    case Map.fetch(params, name) do
      {:ok, value} -> split_on_comma(value)
      :error -> []
    end
  end

  @doc """
  Splits a string on comma, filtering blank values and duplicates.

  ## Examples

      iex> ApiWeb.Params.split_on_comma("a,b,c")
      ["a", "b", "c"]
      iex> ApiWeb.Params.split_on_comma("dup,,dup")
      ["dup"]
      iex> ApiWeb.Params.split_on_comma(nil)
      []
  """
  @spec split_on_comma(String.t() | nil) :: [String.t()]
  def split_on_comma(str) when is_binary(str) and str != "" do
    str
    |> String.splitter(",", trim: true)
    |> Enum.uniq()
  end

  def split_on_comma(_) do
    []
  end

  @doc """
  Parses the direction_id out of a parameter map.
  """
  @spec direction_id(%{String.t() => String.t()}) :: Model.Direction.id() | nil
  def direction_id(params)
  def direction_id(%{"direction_id" => "0"}), do: 0
  def direction_id(%{"direction_id" => "1"}), do: 1
  def direction_id(_), do: nil

  @doc """
  Parses a list of route types out of a parameter map
  """
  @spec route_types(%{String.t() => String.t()}) :: [Model.Route.route_type()]
  def route_types(%{"route_type" => route_types}), do: integer_values(route_types)
  def route_types(_), do: []

  @doc """
  Parse canonical filter param into boolean
  """
  def canonical("true"), do: true
  def canonical("false"), do: false
  def canonical(_), do: nil

  @doc """
  Parse revenue filter to valid params
  """
  def revenue(values) when is_binary(values) do
    values
    |> split_on_comma()
    |> Enum.reduce_while({:ok, []}, fn
      "REVENUE", {:ok, acc} -> {:cont, {:ok, [:REVENUE | acc]}}
      "NON_REVENUE", {:ok, acc} -> {:cont, {:ok, [:NON_REVENUE | acc]}}
      _, _ -> {:halt, :error}
    end)
    |> revenue()
  end

  def revenue({:ok, []}), do: :error
  def revenue(nil), do: :error
  def revenue(val), do: val

  @doc """
  Parses and integer value from params.

  ## Examples

      iex> ApiWeb.Params.parse_int("123")
      {:ok, 123}

      iex> ApiWeb.Params.parse_int("123.4")
      :error

      iex> ApiWeb.Params.parse_int(123)
      {:ok, 123}

      iex> ApiWeb.Params.parse_int(nil)
      :error
  """
  def parse_int(num) when is_integer(num), do: {:ok, num}

  def parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {num, ""} -> {:ok, num}
      _ -> :error
    end
  end

  def parse_int(_val), do: :error

  @doc """
  Returns and integer value from params or nil if invalid or missing.

  ## Examples

      iex> ApiWeb.Params.int("123")
      123

      iex> ApiWeb.Params.int("123.4")
      nil

      iex> ApiWeb.Params.int(123)
      123

      iex> ApiWeb.Params.int(nil)
      nil
  """
  def int(val) do
    case parse_int(val) do
      {:ok, val} -> val
      :error -> nil
    end
  end

  @doc """
  Returns a flattened map of filtered JSON-API query params.

  Query params that are in the `filter` namespace have priority over duplicate
  query params.

  """
  @spec filter_params(map, [String.t()], Plug.Conn.t()) ::
          {:ok, map} | {:error, atom, [String.t()]}
  def filter_params(params, keys, conn) do
    with top_level_params <- Map.drop(params, @default_params),
         {:ok, filtered1} <- validate_filters(top_level_params, keys, conn),
         {:ok, filtered2} <- validate_filters(Map.get(params, "filter"), keys, conn) do
      {:ok, Map.merge(filtered1, filtered2)}
    else
      {:error, _, _} = error -> error
    end
  end

  @spec validate_filters(map, [String.t()], Plug.Conn.t()) ::
          {:ok, map} | {:error, atom, [String.t()]}
  def validate_filters(nil, _keys, _conn), do: {:ok, %{}}

  def validate_filters(params, keys, conn) do
    case params do
      filter when is_map(filter) ->
        bad_filters = Map.keys(filter) -- keys

        if conn.assigns.api_version < "2019-04-05" or bad_filters == [] do
          {:ok, Map.take(filter, keys)}
        else
          {:error, :bad_filter, bad_filters}
        end

      _ ->
        {:ok, %{}}
    end
  end

  @spec validate_includes(map, [String.t()], Plug.Conn.t()) :: :ok | {:error, atom, [String.t()]}
  def validate_includes(_params, _includes, %{assigns: %{api_version: version}})
      when version < "2019-04-05",
      do: :ok

  def validate_includes(%{"include" => values}, includes, _conn) when is_binary(values) do
    split =
      values
      |> String.split(",", trim: true)
      |> Enum.map(&(&1 |> String.split(".") |> List.first()))

    includes_set = MapSet.new(includes)
    bad_includes = Enum.filter(split, fn el -> el not in includes_set end)

    if bad_includes == [] do
      :ok
    else
      {:error, :bad_include, bad_includes}
    end
  end

  def validate_includes(%{"include" => values}, _includes, _conn) when is_map(values) do
    {:error, :bad_include, Map.keys(values)}
  end

  def validate_includes(_params, _includes, _conn), do: :ok

  @spec validate_show_params(map, Plug.Conn.t()) :: :ok | {:error, atom, [String.t()]}
  def validate_show_params(params, conn)

  def validate_show_params(params, %{assigns: %{api_version: version}})
      when version >= "2019-04-05" do
    bad_query_params =
      params
      |> Map.drop(["id", "filter", "include", "fields"])
      |> Map.keys()

    bad_filters =
      case Map.get(params, "filter") do
        %{} = filters ->
          Map.keys(filters)

        _ ->
          []
      end

    case {bad_query_params, bad_filters} do
      {[], []} -> :ok
      {a, b} -> {:error, :bad_filter, a ++ b}
    end
  end

  def validate_show_params(_params, _conn) do
    :ok
  end
end
