defmodule State.Alert do
  @moduledoc """
  Manages the current alerts
  """
  alias State.Alert.{ActivePeriod, InformedEntity, InformedEntityActivity}

  use State.Server,
    indices: [:id],
    parser: Parse.Alerts,
    recordable: Model.Alert,
    hibernate: false

  @subscriptions [
    {:new_state, State.Route},
    {:new_state, State.Stop},
    {:new_state, State.Trip}
  ]

  @subtables [ActivePeriod, InformedEntity, InformedEntityActivity]

  @type filter_opts :: %{
          optional(:ids) => [Model.Alert.id()],
          optional(:routes) => [Model.Route.id() | nil],
          optional(:route_types) => [0..4 | nil],
          optional(:trips) => [Model.Trip.id() | nil],
          optional(:direction_id) => Model.Direction.id(),
          optional(:stops) => [Model.Stop.id() | nil],
          optional(:facilities) => [Model.Facility.id() | nil],
          optional(:activities) => [Model.Alert.activity()],
          optional(:datetime) => DateTime.t(),
          optional(:severity) => [Model.Alert.severity() | nil]
        }

  def by_id(id) do
    case super(id) do
      [] -> nil
      [alert] -> alert
    end
  end

  @doc """
  Filters alerts.

  The filter keys are:
  * ids (list of alert IDs)
  * routes (list of route IDs)
  * route_types (list of route types 0, 1, 2, 3, 4)
  * direction_id (a direction ID)
  * trips (list of trip IDs)
  * stops (list of stop IDs)
  * facilities (list of facility IDs)
  * activities (list of alert activities)
  * datetime (DateTime.t for when the alert is active)
  * lifecycles (list)
  * severity (list of severity levels (0 to 10))
  """
  @spec filter_by(filter_opts) :: [Model.Alert.t()]
  defdelegate filter_by(filter_opts), to: State.Alert.Filter

  @impl GenServer
  def init(_) do
    Enum.each(@subscriptions, &subscribe/1)
    for table <- @subtables, do: table.new()
    super(nil)
  end

  @impl Events.Server
  def handle_event(_, _, _, state) do
    # Re-process the current state to execute hooks
    handle_new_state(all())
    {:noreply, state}
  end

  @impl State.Server
  def post_commit_hook do
    all_alerts = all()
    for table <- @subtables, do: table.update(all_alerts)
    :ok
  end

  @impl State.Server
  defdelegate pre_insert_hook(alert), to: State.Alert.Hooks
end
