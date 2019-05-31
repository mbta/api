defmodule ApiWeb.ApiControllerHelpers do
  @moduledoc """

  Helpers for Api Controllers.  Requires an index_data/2 and show_data/2
  callback to return data.

  """
  @callback index_data(Plug.Conn.t(), map) :: any
  @callback show_data(Plug.Conn.t(), map) :: any

  import Plug.Conn, only: [assign: 3, put_status: 2]
  import Phoenix.Controller, only: [render: 3, put_view: 2, get_format: 1]

  alias ApiWeb.ApiControllerHelpers
  alias State.Pagination.Offsets

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour ApiControllerHelpers

      defdelegate split_include(conn, opts), to: ApiControllerHelpers

      plug(:split_include)
      plug(ApiWeb.Plugs.ModifiedSinceHandler, caller: __MODULE__)
      plug(ApiWeb.Plugs.RateLimiter)

      def index(conn, params), do: ApiControllerHelpers.index(__MODULE__, conn, params)

      def show(conn, params), do: ApiControllerHelpers.show(__MODULE__, conn, params)

      def state_module, do: nil

      defoverridable index: 2, show: 2, state_module: 0
    end
  end

  def index(module, conn, params) do
    conn
    |> get_format()
    |> index_for_format()
    |> apply(:call, [conn, module, params])
  end

  def call(conn, module, params) do
    case module.index_data(conn, params) do
      {:error, error} ->
        conn
        |> put_status(:bad_request)
        |> put_view(ApiWeb.ErrorView)
        |> render("400.json-api", error: error)

      data ->
        render_index(conn, params, data)
    end
  end

  def index_for_format("event-stream"), do: ApiWeb.EventStream
  def index_for_format(_), do: __MODULE__

  def render_index(conn, params, {data, %Offsets{} = offsets}) do
    pagination_links = pagination_links(conn, offsets)

    opts =
      params
      |> ApiControllerHelpers.opts_for_params()
      |> Keyword.put(:page, pagination_links)

    render(conn, "index.json-api", data: data, opts: opts)
  end

  def render_index(conn, _params, {:error, error, details}) do
    conn
    |> put_status(:bad_request)
    |> put_view(ApiWeb.ErrorView)
    |> render("400.json-api", error: error, details: details)
  end

  def render_index(conn, params, data) do
    render(
      conn,
      "index.json-api",
      data: data,
      opts: ApiControllerHelpers.opts_for_params(params)
    )
  end

  def render_show(conn, _params, nil) do
    conn
    |> put_status(:not_found)
    |> put_view(ApiWeb.ErrorView)
    |> render("404.json-api", [])
  end

  def render_show(conn, _params, {:error, error, details}) do
    conn
    |> put_status(:bad_request)
    |> put_view(ApiWeb.ErrorView)
    |> render("400.json-api", error: error, details: details)
  end

  def render_show(conn, params, data) do
    render(conn, "show.json-api", data: data, opts: ApiControllerHelpers.opts_for_params(params))
  end

  def show(module, conn, params) do
    data =
      with :ok <- ApiWeb.Params.validate_show_params(params, conn) do
        module.show_data(conn, params)
      else
        {:error, _, _} = error -> error
      end

    ApiControllerHelpers.render_show(conn, params, data)
  end

  def opts_for_params(params) when is_map(params) do
    fields = filter_valid_field_params(Map.get(params, "fields"))

    [
      include: Map.get(params, "include"),
      fields: fields
    ]
  end

  @doc """
  Filters for valid types with valid field attributes.

  Invalid attributes, invalid types, and types without any valid attributes are
  removed.
  """
  @spec filter_valid_field_params(map | nil) :: map
  def filter_valid_field_params(nil), do: nil

  def filter_valid_field_params(fields) do
    for {type, _} = field <- fields, valid_type?(type), into: %{} do
      attributes = do_filter_valid_field_attributes(field)
      {type, attributes}
    end
  end

  # Filter types for types with a view like ShapeView or RouteView
  defp valid_type?(type) do
    view_module = view_module_for_type(type)
    Code.ensure_compiled?(view_module)
  rescue
    ArgumentError -> false
  end

  # Filter requested fields for valid field attributes supported in the view
  defp do_filter_valid_field_attributes({type, nil}),
    do: do_filter_valid_field_attributes({type, ""})

  defp do_filter_valid_field_attributes({_type, ""}), do: []

  defp do_filter_valid_field_attributes({type, fields}) do
    view_module = view_module_for_type(type)

    case view_module.__attributes() do
      [_ | _] = attributes ->
        attribute_set = MapSet.new(attributes, &Atom.to_string/1)

        fields
        |> String.split(",")
        |> Enum.filter(&MapSet.member?(attribute_set, &1))
        |> Enum.map(&String.to_existing_atom/1)
    end
  end

  defp view_module_for_type(type) do
    view_name = String.capitalize(type) <> "View"
    Module.safe_concat([ApiWeb, view_name])
  end

  def split_include(%{params: params} = conn, []) do
    split_include =
      case params do
        %{"include" => include} when is_binary(include) ->
          include
          |> String.split([",", "."])
          |> MapSet.new()

        _ ->
          []
      end

    assign(conn, :split_include, split_include)
  end

  @doc false
  def pagination_links(conn, %Offsets{} = offsets) do
    offsets
    |> Map.from_struct()
    |> Enum.map(&build_pagination_link(&1, conn))
  end

  defp build_pagination_link({_key, nil} = key_pair, _conn), do: key_pair

  defp build_pagination_link({key, offset}, conn) do
    pagination_url = generate_pagination_url(conn, offset)
    {key, pagination_url}
  end

  defp generate_pagination_url(conn, offset) do
    new_params = update_in(conn.query_params, ["page"], &Map.put(&1, "offset", offset))

    new_path = conn.request_path <> "?" <> Plug.Conn.Query.encode(new_params)
    endpoint_module = Phoenix.Controller.endpoint_module(conn)
    Path.join(endpoint_module.url(), new_path)
  end
end
