defmodule Fetch.FileTap do
  @moduledoc """
  Log files the API fetches for future inspection.
  """
  use GenServer

  def start_link(opts \\ [name: __MODULE__]) do
    config = Application.get_env(:fetch, FileTap)
    GenServer.start_link(__MODULE__, config, opts)
  end

  def log_body(url, body, fetch_dt) do
    GenServer.cast(__MODULE__, {:log_body, url, body, fetch_dt})
  end

  def init(config) do
    state =
      if module = config[:module] do
        max_tap_size = Keyword.get(config, :max_tap_size, :infinity)
        %{module: module, max_tap_size: max_tap_size}
      else
        %{}
      end

    {:ok, state}
  end

  def handle_cast({:log_body, url, body, fetch_dt}, %{module: module} = state) do
    if byte_size(body) < state.max_tap_size do
      module.log_body(url, body, fetch_dt)
    end

    {:noreply, state}
  end

  def handle_cast({:log_body, _url, _body, _fetch_dt}, state) do
    # not logging the responses, so throw it away
    {:noreply, state}
  end
end
