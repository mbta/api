defmodule ALBMonitor.Monitor do
  @moduledoc "See `ALBMonitor`."

  use GenServer

  alias ExAws.ElasticLoadBalancingV2, as: ALB

  require Logger

  @ex_aws Application.compile_env!(:alb_monitor, :ex_aws)
  @http Application.compile_env!(:alb_monitor, :http)

  defmodule State do
    @moduledoc "State of the GenServer."
    defstruct check_interval: 5_000,
              ecs_metadata_uri: nil,
              instance_ip: nil,
              shutdown_fn: &:init.stop/0,
              target_group_arn: nil

    def default do
      %__MODULE__{
        ecs_metadata_uri: Application.get_env(:alb_monitor, :ecs_metadata_uri),
        target_group_arn: Application.get_env(:alb_monitor, :target_group_arn)
      }
    end
  end

  @spec start_link(%State{}) :: GenServer.on_start()
  def start_link(initial_state \\ State.default()) do
    GenServer.start_link(__MODULE__, initial_state)
  end

  @impl true
  def init(%State{} = state) do
    schedule_check(state)
    {:ok, state}
  end

  @impl true
  def handle_info(:check, %State{instance_ip: nil} = state) do
    new_state = %{state | instance_ip: get_instance_ip(state)}
    schedule_check(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check, %State{shutdown_fn: shutdown} = state) do
    case get_instance_health(state) do
      "draining" ->
        log_info("shutdown")
        shutdown.()
        {:stop, nil, state}

      _ ->
        schedule_check(state)
        {:noreply, state}
    end
  end

  # https://github.com/benoitc/hackney/issues/464
  @impl true
  def handle_info({:ssl_closed, _}, state), do: {:noreply, state}

  defp get_instance_health(%State{instance_ip: instance_ip, target_group_arn: target_group}) do
    with {:ok, %{body: %{target_health_descriptions: health_descs}}} <-
           target_group |> ALB.describe_target_health() |> @ex_aws.request(),
         %{target_health: health} <-
           Enum.find(health_descs, &match?(%{targets: [%{id: ^instance_ip}]}, &1)) do
      health
    else
      unmatched ->
        log_warn("get_instance_health failed: #{inspect(unmatched)}")
        nil
    end
  end

  defp get_instance_ip(%State{ecs_metadata_uri: nil}) do
    # likely not running on ECS
    log_info("no_ecs_metadata_uri")
    nil
  end

  defp get_instance_ip(%State{ecs_metadata_uri: ecs_metadata_uri}) do
    with {:ok, %{body: body}} <- @http.get(ecs_metadata_uri),
         {:ok, %{"Networks" => [%{"IPv4Addresses" => [ip_address]}]}} <- Jason.decode(body) do
      ip_address
    else
      unmatched ->
        log_warn("get_instance_ip failed: #{inspect(unmatched)}")
        nil
    end
  end

  defp log_warn(message) when is_binary(message), do: Logger.warn(["alb_monitor ", message])
  defp log_info(message) when is_binary(message), do: Logger.info(["alb_monitor ", message])

  defp schedule_check(%State{check_interval: check_interval}) do
    Process.send_after(self(), :check, check_interval)
  end
end
