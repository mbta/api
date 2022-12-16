defmodule ApiWeb.Plugs.ModifiedSinceHandler do
  @moduledoc """
  Checks for the `If-Modified-Since` header.

  Whenever the header is found, the value is parsed and compared to a the value
  returned from an expected state module. If a resource hasn't been updated
  since the provided timestamp, a 304 status is given. Otherwise, the lastest
  data is fetched.

  Refer to:
  https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Modified-Since

  ## Expected Date Format

  The expected format is `Wed, 21 Oct 2015 07:28:00 GMT`.

  ## Expected Usage

  The plug is expected to be used at the controller level where a state module
  can be provided/known or in `ApiWeb.ApiControllerHelpers`.

      defmodule ApiWeb.ResourceController
        use Phoenix.Controller
        plug ApiWeb.Plugs.ModifiedSinceHandler, caller: __MODULE__

        #...

        def state_module, do: State.Resource
      end

  """
  import Plug.Conn

  @doc """
  Configures the plug.

  ## Options
    * `:caller` - (Required) Module calling the plug. Module should define
      `state_module/0`, which returns a State module.
  """
  def init(opts) do
    _ = ensure_caller_defined(opts)
    opts
  end

  def call(conn, opts) do
    _ = ensure_caller_defined(opts)
    _ = ensure_state_module_implemented(opts)

    with mod when mod != nil <- state_module(opts),
         last_modified_header = State.Metadata.last_modified_header(mod),
         conn = Plug.Conn.put_resp_header(conn, "last-modified", last_modified_header),
         {conn, [if_modified_since_header]} <- {conn, get_req_header(conn, "if-modified-since")},
         {conn, false} <- {conn, is_modified?(last_modified_header, if_modified_since_header)} do
      conn
      |> send_resp(:not_modified, "")
      |> halt()
    else
      {%Plug.Conn{} = conn, _error} ->
        conn

      _error ->
        conn
    end
  end

  def is_modified?(same, same) do
    # shortcut if the headers have the same value
    false
  end

  def is_modified?(first, second) do
    with {:ok, first_val} <- modified_value(first),
         {:ok, second_val} <- modified_value(second) do
      first_val > second_val
    else
      _ -> true
    end
  end

  defp modified_value(
         <<_::binary-5, day::binary-2, " ", month_str::binary-3, " ", year::binary-4, " ",
           time::binary-8, " GMT">>
       ) do
    {:ok, month} = month_val(month_str)
    {:ok, {year, month, day, time}}
  end

  defp modified_value(_) do
    :error
  end

  for {month_str, index} <- Enum.with_index(~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)) do
    defp month_val(unquote(month_str)), do: {:ok, unquote(index)}
  end

  defp month_val(_), do: :error

  defp state_module(opts) do
    opts[:caller].state_module()
  end

  if Application.compile_env(:api_web, __MODULE__)[:check_caller] do
    defp ensure_caller_defined(opts) do
      unless opts[:caller] do
        raise ArgumentError, "expected `:caller` to be provided with module"
      end
    end

    defp ensure_state_module_implemented(opts) do
      unless opts[:caller].module_info(:exports)[:state_module] == 0 do
        raise ArgumentError,
              "expected `:caller` to implement " <>
                "`state_module/0` and return a module from the " <> "`State` namespace"
      end
    end
  else
    defp ensure_caller_defined(_), do: :ok
    defp ensure_state_module_implemented(_), do: :ok
  end
end
