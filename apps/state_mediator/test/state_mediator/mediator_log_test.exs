defmodule StateMediator.MediatorLogTest do
  use ExUnit.Case
  import ExUnit.CaptureLog, only: [capture_log: 1]
  alias StateMediator.Mediator

  test "logs a fetch timeout as a warning" do
    assert capture_log(fn ->
             Mediator.handle_response(
               {:error,
                %HTTPoison.Error{
                  id: nil,
                  reason: :timeout
                }},
               %{module: nil, retries: 0}
             )
           end) =~ "[warn]"
  end

  test "logs an unknown error as an error" do
    assert capture_log(fn ->
             Mediator.handle_response(
               {:error,
                %HTTPoison.Error{
                  id: nil,
                  reason: :heat_death_of_universe
                }},
               %{module: nil, retries: 0}
             )
           end)
  end
end
