defmodule State.Stop.WorkerTest do
  use ExUnit.Case, async: true
  alias Model.Stop

  setup do
    worker_id = :test
    {:ok, _} = State.Stop.Worker.start_link(worker_id)

    {:ok, %{worker_id: worker_id}}
  end

  test "it can add a stop and query it", %{worker_id: worker_id} do
    stop = %Stop{id: "1", name: "stop", latitude: 1, longitude: -2}
    State.Stop.Worker.new_state(worker_id, [stop])

    assert State.Stop.Worker.around(worker_id, 1.001, -2.002) == ["1"]
  end
end
