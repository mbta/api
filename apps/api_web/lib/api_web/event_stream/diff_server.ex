defmodule ApiWeb.EventStream.DiffServer do
  @moduledoc """
  GenServer responsible for sending EventStream diffs back to the process holding the conn.

  The original implemntation of this feature had each client doing the diff
  itself. However, when multiple clients are subscribed to the same data,
  this results in a lot of duplicated diffing effort.

  This new implementation does the diffing once, and sends the diffs to each client.
  """
  use GenServer
  alias ApiWeb.EventStream.Diff

  def start_link({conn, module, opts}) do
    if module.state_module() do
      GenServer.start_link(__MODULE__, {conn, module}, opts)
    else
      {:error, :no_state_module}
    end
  end

  def subscribe(pid) do
    GenServer.cast(pid, {:subscribe, self()})
  end

  def unsubscribe(pid) do
    GenServer.cast(pid, {:unsubscribe, self()})
  end

  defmodule State do
    @moduledoc false
    defstruct [
      :conn,
      :view_module,
      :opts,
      :module,
      last_data: nil,
      last_rendered: nil,
      refs: %{},
      subscribed?: false
    ]
  end

  alias __MODULE__.State

  @impl GenServer
  def init({conn, module}) do
    state = %State{
      conn: conn,
      view_module: Phoenix.Controller.view_module(conn),
      opts: ApiWeb.ApiControllerHelpers.opts_for_params(conn, conn.params),
      module: module
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:subscribe, parent}, state) do
    case state.refs do
      %{^parent => _} ->
        {:noreply, state}

      refs ->
        ref = Process.monitor(parent)
        state = %{state | refs: Map.put(refs, parent, ref)}

        state =
          cond do
            not is_nil(state.last_rendered) ->
              send(parent, {:events, [{"reset", Jason.encode_to_iodata!(state.last_rendered)}]})
              state

            state.subscribed? ->
              state

            true ->
              Events.subscribe({:new_state, state.module.state_module()})
              send(self(), {:event, :initial, :timeout, :event})
              %{state | subscribed?: true}
          end

        {:noreply, state}
    end
  end

  def handle_cast({:unsubscribe, parent}, state) do
    {parent_ref, refs} = Map.pop(state.refs, parent)
    Process.demonitor(parent_ref, [:flush])
    state = %{state | refs: refs}

    if refs == %{} do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:event, _, _, _}, state) do
    :ok = receive_all_events()

    case state.module.index_data(state.conn, state.conn.params) do
      {:error, error} ->
        respond_with_error(state, error)

      {data, _} ->
        respond_with_data(state, data)

      data ->
        respond_with_data(state, data)
    end
  end

  def handle_info(
        {:DOWN, parent_ref, :process, parent, _},
        %{refs: refs} = state
      ) do
    {^parent_ref, refs} = Map.pop(refs, parent)
    state = %{state | refs: refs}

    if refs == %{} do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def respond_with_error(state, error) do
    _error_sends =
      for parent <- Map.keys(state.refs) do
        send(parent, {:error, render_error(error)})
      end

    {:stop, :normal, state}
  end

  def respond_with_data(%{last_data: data} = state, data) do
    {:noreply, state}
  end

  def respond_with_data(state, data) do
    rendered = render_data(state, data)
    events = diff_events(state.last_rendered, rendered)

    _event_sends =
      for parent <- Map.keys(state.refs) do
        send(parent, {:events, events})
      end

    {:noreply, %{state | last_data: data, last_rendered: rendered}}
  end

  defp render_data(state, data) do
    json_api = JaSerializer.format(state.view_module, data, state.conn, state.opts)
    Map.get(json_api, "included", []) ++ Map.get(json_api, "data", [])
  end

  @doc """
  JaSerializer renders into a map that looks like:

  ```
  %{
    "data" => [
      %{"type" => "vehicle", "id" => "y1234", ...},
      ...
    ],
    "included" => [ # optional
      %{"type" => "route", "id" => "5", ...}
    ]
  }
  ```

  `data` is a list of items from the primary source (here,
  vehicles). `included` is an optional array of related items (here, route)
  that have relationships to the primary data or other included items.

  `diff_events/2` takes two of those maps, and returns a list of {event_name, json}
  pairs, where event_name is either "add", "update", "remove", or "reset"
  representing whether the item was added, updated, or removed from the
  previous JSON-API output.

  """
  def diff_events(previous, current) do
    diff = Diff.diff(previous, current)

    for type <- ~w(add update remove reset)a,
        items = Map.get(diff, type, []),
        items != [],
        type = Atom.to_string(type),
        item <- items do
      json = Jason.encode_to_iodata!(item)
      {type, json}
    end
  end

  defp render_error(error) do
    Phoenix.View.render_to_iodata(ApiWeb.ErrorView, "400.json-api", error: error)
  end

  defp receive_all_events do
    # pull any extra {:event, _, _, _} off the message queue
    receive do
      {:event, _, _, _} ->
        receive_all_events()
    after
      0 -> :ok
    end
  end
end
