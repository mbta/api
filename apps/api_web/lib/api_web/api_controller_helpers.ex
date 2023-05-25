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
  alias ApiWeb.Plugs.Deadline
  alias State.Pagination.Offsets

  # # of milliseconds after which to terminate the request
  @deadline_ms 10_000

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
    import ExProf.Macro

    {_, result} =
      profile do
        conn
        |> get_format()
        |> index_for_format()
        |> apply(:call, [conn, module, params])
      end

    result
  end

  def call(conn, module, params) do
    conn = Deadline.set(conn, @deadline_ms)
    data = module.index_data(conn, params)
    render_json_api(conn, params, data)
  end

  def show(module, conn, params) do
    conn
    |> get_format()
    |> show_for_format(module, conn, params)
  end

  def show_for_format("event-stream", _module, conn, params) do
    render_json_api(
      conn,
      params,
      {:error, :not_acceptable,
       "Streaming not supported for an individual resource. Instead list resources and filter by ID."}
    )
  end

  def show_for_format(_format, module, conn, params) do
    data =
      case ApiWeb.Params.validate_show_params(params, conn) do
        :ok ->
          module.show_data(conn, params)

        error ->
          error
      end

    render_json_api(conn, params, data)
  end

  def index_for_format("event-stream"), do: ApiWeb.EventStream
  def index_for_format(_), do: __MODULE__

  def render_json_api(conn, params, {data, %Offsets{} = offsets}) do
    Deadline.check!(conn)
    pagination_links = pagination_links(conn, offsets)

    opts =
      conn
      |> ApiControllerHelpers.opts_for_params(params)
      |> Map.put(:page, pagination_links)

    render(conn, "index.json-api", data: data, opts: opts)
  end

  def render_json_api(conn, params, data) when is_list(data) do
    Deadline.check!(conn)

    render(
      conn,
      "index.json-api",
      data: data,
      opts: ApiControllerHelpers.opts_for_params(conn, params)
    )
  end

  def render_json_api(conn, params, %{} = data) do
    Deadline.check!(conn)

    render(conn, "show.json-api",
      data: data,
      opts: ApiControllerHelpers.opts_for_params(conn, params)
    )
  end

  def render_json_api(conn, _params, nil) do
    conn
    |> put_status(:not_found)
    |> put_view(ApiWeb.ErrorView)
    |> render("404.json-api", [])
  end

  def render_json_api(conn, _params, {:error, :not_acceptable, details}) do
    conn
    |> put_status(:not_acceptable)
    |> put_view(ApiWeb.ErrorView)
    |> render("406.json-api", details: details)
  end

  def render_json_api(conn, _params, {:error, error, details}) do
    conn
    |> put_status(:bad_request)
    |> put_view(ApiWeb.ErrorView)
    |> render("400.json-api", error: error, details: details)
  end

  def render_json_api(conn, _params, {:error, error}) do
    conn
    |> put_status(:bad_request)
    |> put_view(ApiWeb.ErrorView)
    |> render("400.json-api", error: error)
  end

  def opts_for_params(conn, params) when is_map(params) do
    fields = filter_valid_field_params(conn, Map.get(params, "fields"))

    %{
      include: Map.get(params, "include"),
      fields: fields
    }
  end

  @doc """
  Filters for valid types with valid field attributes.

  Invalid attributes, invalid types, and types without any valid attributes are
  removed.
  """
  @spec filter_valid_field_params(Plug.Conn.t(), term) :: map
  def filter_valid_field_params(conn, %{} = fields) do
    for {type, _} = field <- fields, valid_type?(type), into: %{} do
      attributes = do_filter_valid_field_attributes(conn, field)
      {type, attributes}
    end
  end

  def filter_valid_field_params(_conn, _params), do: nil

  # Filter types for types with a view like ShapeView or RouteView
  defp valid_type?(type) do
    view_module = view_module_for_type(type)

    case Code.ensure_compiled(view_module) do
      {:module, ^view_module} -> true
      {:error, :nofile} -> false
    end
  rescue
    ArgumentError -> false
  end

  # Filter requested fields for valid field attributes supported in the view
  defp do_filter_valid_field_attributes(conn, {type, nil}),
    do: do_filter_valid_field_attributes(conn, {type, ""})

  defp do_filter_valid_field_attributes(_conn, {_type, ""}), do: []

  defp do_filter_valid_field_attributes(conn, {type, fields}) do
    view_module = view_module_for_type(type)

    attr_filter = fn attr -> conn |> view_module.attribute_set |> MapSet.member?(attr) end

    fields
    |> String.split(",")
    |> Enum.filter(attr_filter)
    |> Enum.map(&String.to_existing_atom/1)
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
