defmodule ALBMonitor.MonitorTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Mox
  setup :verify_on_exit!

  alias ALBMonitor.Monitor

  test "calls the shutdown function if the ECS instance's health status is draining" do
    mock_instance_ip("10.0.0.2")
    mock_health_response([{"10.0.0.1", "healthy"}, {"10.0.0.2", "draining"}])

    ref = start!()

    assert_receive {:DOWN, ^ref, :process, _, :normal}
  end

  test "does not stop if the instance's health is not draining" do
    mock_instance_ip("10.0.0.2")
    mock_health_response([{"10.0.0.1", "draining"}, {"10.0.0.2", "healthy"}])

    ref = start!()

    refute_receive {:DOWN, ^ref, :process, _, _}
  end

  test "logs a warning and keeps trying if the instance meta request fails" do
    stub(FakeHTTP, :get, fn "fake_meta_uri" -> {:error, %{body: "metadata error"}} end)
    mock_health_response([{"10.0.0.1", "draining"}])

    logs =
      capture_log(fn ->
        ref = start!()
        refute_receive {:DOWN, ^ref, :process, _, _}

        mock_instance_ip("10.0.0.1")
        assert_receive {:DOWN, ^ref, :process, _, _}
      end)

    assert logs =~ "get_instance_ip failed"
    assert logs =~ "metadata error"
  end

  test "remains quiet if the metadata URI is not present in the environment" do
    logs =
      capture_log(fn ->
        ref = start!(ecs_metadata_uri: nil)
        refute_receive {:DOWN, ^ref, :process, _, _}
      end)

    refute logs =~ "get_instance_ip"
  end

  test "logs a warning and keeps trying if the target health request fails" do
    mock_instance_ip("10.0.0.1")
    stub(FakeAws, :request, fn _ -> {:error, %{body: "health error"}} end)

    logs =
      capture_log(fn ->
        ref = start!()
        refute_receive {:DOWN, ^ref, :process, _, _}

        mock_health_response([{"10.0.0.1", "draining"}])
        assert_receive {:DOWN, ^ref, :process, _, _}
      end)

    assert logs =~ "get_instance_health failed"
    assert logs =~ "health error"
  end

  test "logs a warning and keeps trying if the instance's IP is not found in the health status" do
    mock_instance_ip("10.0.0.1")
    mock_health_response([{"10.0.0.2", "healthy"}])

    logs =
      capture_log(fn ->
        ref = start!()
        refute_receive {:DOWN, ^ref, :process, _, _}

        mock_health_response([{"10.0.0.1", "draining"}, {"10.0.0.2", "healthy"}])
        assert_receive {:DOWN, ^ref, :process, _, _}
      end)

    assert logs =~ "get_instance_health failed: nil"
  end

  defp start!(overrides \\ []) do
    test_pid = self()

    initial_state =
      %Monitor.State{
        # chosen to fit comfortably within the default 100ms `assert_receive` timeout
        check_interval: 10,
        ecs_metadata_uri: "fake_meta_uri",
        target_group_arn: "fake_target_group"
      }
      |> struct!(overrides)

    {:ok, monitor_pid} = Monitor.start_link(initial_state)
    allow(FakeAws, test_pid, monitor_pid)
    allow(FakeHTTP, test_pid, monitor_pid)

    Process.monitor(monitor_pid)
  end

  defp mock_instance_ip(ip) when is_binary(ip) do
    meta_response = Jason.encode!(%{"Networks" => [%{"IPv4Addresses" => [ip]}]})
    expect(FakeHTTP, :get, fn "fake_meta_uri" -> {:ok, %{body: meta_response}} end)
  end

  defp mock_health_response(targets) when is_list(targets) do
    # `stub` allows calling any number of times, which may be the case here
    stub(FakeAws, :request, fn %{
                                 params: %{
                                   "Action" => "DescribeTargetHealth",
                                   "TargetGroupArn" => "fake_target_group"
                                 }
                               } ->
      {:ok,
       %{
         body: %{
           target_health_descriptions:
             Enum.map(targets, fn {id, health} ->
               %{target_health: health, targets: [%{id: id}]}
             end)
         }
       }}
    end)
  end
end
