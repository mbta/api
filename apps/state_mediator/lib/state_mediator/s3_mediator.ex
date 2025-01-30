defmodule StateMediator.S3Mediator do
  @moduledoc """

  S3Mediator is responsible for reading files from an S3 bucket and
  sending messages to the state module.

  """

  defstruct [
    :module,
    :bucket_arn,
    :object,
    :sync_timeout,
    :interval
  ]

  @opaque t :: %__MODULE__{
            module: module,
            bucket_arn: String.t(),
            object: String.t(),
            sync_timeout: pos_integer()
          }

  use GenServer
  require Logger
  alias ExAws.S3

  def child_spec(opts) do
    {spec_id, opts} = Keyword.pop!(opts, :spec_id)

    %{
      id: spec_id,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec start_link(Keyword.t()) :: {:ok, pid}
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @spec stop(pid) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @spec init(Keyword.t()) :: {:ok, __MODULE__.t()} | no_return
  def init(options) do
    state_module = Keyword.fetch!(options, :state)

    bucket_arn = Keyword.fetch!(options, :bucket_arn)
    object = Keyword.fetch!(options, :object)
    sync_timeout = options |> Keyword.get(:sync_timeout, 5000)
    interval = options |> Keyword.get(:interval, 5000)

    send(self(), :initial)

    {:ok,
     %__MODULE__{
       interval: interval,
       module: state_module,
       bucket_arn: bucket_arn,
       object: object,
       sync_timeout: sync_timeout
     }}
  end

  @spec handle_info(:initial | :timeout, t) :: {:noreply, t} | {:noreply, t, :hibernate}
  def handle_info(:initial, %{module: state_module} = state) do
    _ = Logger.debug(fn -> "#{__MODULE__} #{state_module} initial sync starting" end)
    fetch(state)
  end

  def handle_info(:timeout, %{module: state_module} = state) do
    _ = Logger.debug(fn -> "#{__MODULE__} #{state_module} timeout sync starting" end)
    fetch(state)
  end

  defp fetch(%{bucket_arn: bucket_arn, object: object} = state) do
    aws_response =
      S3.get_object(bucket_arn, object)
      |> ExAws.request()

    handle_response(aws_response, state)
  end

  def handle_response(
         {:ok, %{body: body}},
         %{sync_timeout: sync_timeout, module: state_module} = state
       ) do
    {:ok, json} = Jason.decode(body)
    IO.inspect(json)
    debug_time("#{state_module} new state", fn -> state_module.new_state(body, sync_timeout) end)

    schedule_update(state)
  end

  def handle_response(
         response,
         state
       ) do
    Logger.warning(
      "Received unknown response when getting commuter rail occupancies from S3: #{inspect(response)}"
    )

    schedule_update(state)
  end

  defp schedule_update(%{interval: interval} = state) when interval != nil do
    {:noreply, state, interval}
  end

  defp debug_time(description, func) do
    State.Logger.debug_time(func, fn milliseconds ->
      "#{__MODULE__} #{description} took #{milliseconds}ms"
    end)
  end
end
