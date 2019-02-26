defmodule ApiWeb.Params do
  @moduledoc """
  Parses request params into domain datastructures.
  """

  ## Defaults

  @max_limit 100
  @default_params ~w(include sort page filter fields)

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

      iex> ApiWeb.Params.filter_opts(%{"page" => %{"offset" => 0}}, [:offset])
      [offset: 0]

      iex> ApiWeb.Params.filter_opts(%{"page" => %{"limit" => 10}}, [:limit])
      [limit: 10]

      iex> ApiWeb.Params.filter_opts(%{"sort" => "name"}, [:order_by])
      [order_by: [{:name, :asc}]]

      iex> ApiWeb.Params.filter_opts(%{"sort" => "-name,value"}, [:order_by])
      [order_by: [{:name, :desc}, {:value, :asc}]]
  """
  def filter_opts(params, options, acc \\ []) do
    Enum.reduce(options, acc, fn opt, acc ->
      filter_opt(opt, params, acc)
    end)
  end

  defp filter_opt(:offset, %{"page" => %{"offset" => offset}}, acc) do
    case parse_int(offset) do
      {:ok, offset} when offset >= 0 -> [{:offset, offset} | acc]
      _ -> acc
    end
  end

  defp filter_opt(:offset, _params, acc), do: acc

  defp filter_opt(:limit, %{"page" => %{"limit" => limit}}, acc) do
    case parse_int(limit) do
      {:ok, limit} when limit > 0 and limit <= @max_limit ->
        [{:limit, limit} | acc]

      _ ->
        acc
    end
  end

  defp filter_opt(:limit, _params, acc), do: acc

  defp filter_opt(:distance, %{"filter" => %{"latitude" => lat, "longitude" => lng}}, acc),
    do: [{:latitude, lat}, {:longitude, lng} | acc]

  defp filter_opt(:distance, %{"filter" => %{"latitude" => lat}, "longitude" => lng}, acc),
    do: [{:latitude, lat}, {:longitude, lng} | acc]

  defp filter_opt(:distance, %{"filter" => %{"longitude" => lng}, "latitude" => lat}, acc),
    do: [{:latitude, lat}, {:longitude, lng} | acc]

  defp filter_opt(:distance, %{"longitude" => lng, "latitude" => lat}, acc),
    do: [{:latitude, lat}, {:longitude, lng} | acc]

  defp filter_opt(:distance, _params, acc), do: acc

  defp filter_opt(:order_by, %{"sort" => fields}, acc) do
    order_by =
      for field <- split_on_comma(fields) do
        case field do
          "-" <> desc_field ->
            {String.to_existing_atom(desc_field), :desc}

          asc_field ->
            {String.to_existing_atom(asc_field), :asc}
        end
      end

    [{:order_by, order_by} | acc]
  rescue
    ArgumentError -> acc
  end

  defp filter_opt(:order_by, _params, acc), do: acc

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
  Fetches and casts latitude, longitude, and optional radius form params.
  """
  def fetch_coords(%{"latitude" => lat, "longitude" => long} = params) do
    with {parsed_lat, ""} <- Float.parse(lat),
         {parsed_long, ""} <- Float.parse(long),
         {radius, ""} <- Float.parse(params["radius"] || "0.01") do
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
    |> String.split(",")
    |> Enum.reject(&(&1 == ""))
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

  ## Examples

      iex> ApiWeb.Params.filter_params(%{"sort" => "1,2,3"}, ["sort"])
      {:ok, %{}}

      iex> ApiWeb.Params.filter_params(%{"sort" => "1,2,3", "route" => "1,2,3"},
      ...>   ["route"])
      {:ok, %{"route" => "1,2,3"}}

      iex(1)> params = %{
      ...>      "sort" => "1,2,3",
      ...>      "filter" => %{
      ...>        "sort" => "4,5,6",
      ...>        "route" => "1,2,3"
      ...>      }
      ...>    }
      iex(2)> ApiWeb.Params.filter_params(params, ["sort", "route"])
      {:ok, %{"sort" => "4,5,6", "route" => "1,2,3"}}

      iex> ApiWeb.Params.filter_params(%{"sort" => "1,2,3"}, [])
      {:ok, %{}}

  """
  @spec filter_params(map, [String.t()]) :: {:ok, map} | {:error, atom, [String.t()]}
  def filter_params(params, keys) do
    with top_level_params <- Map.drop(params, @default_params),
         {:ok, filtered1} <- validate_filters(top_level_params, keys),
         {:ok, filtered2} <- validate_filters(Map.get(params, "filter"), keys) do
      {:ok, Map.merge(filtered1, filtered2)}
    else
      {:error, _, _} = error -> error
    end
  end

  @spec validate_filters(map, [String.t()]) :: {:ok, map} | {:error, atom, [String.t()]}
  def validate_filters(nil, _keys), do: {:ok, %{}}

  def validate_filters(params, keys) do
    case params do
      filter when is_map(filter) ->
        bad_filters = Map.keys(filter) -- keys

        if bad_filters == [] do
          {:ok, Map.take(filter, keys)}
        else
          {:error, :bad_filter, bad_filters}
        end

      _ ->
        {:ok, %{}}
    end
  end

  @spec validate_includes(map, [String.t()]) :: {:ok, [String.t()]} | {:error, atom, [String.t()]}
  def validate_includes(params, includes) do
    case Map.get(params, "include") do
      values when is_binary(values) ->
        split =
          values
          |> String.split(",", trim: true)
          |> Enum.map(&(&1 |> String.split(".") |> List.first()))

        bad_includes = split -- includes

        if bad_includes == [] do
          {:ok, split}
        else
          {:error, :bad_include, bad_includes}
        end

      _ ->
        {:ok, nil}
    end
  end
end
