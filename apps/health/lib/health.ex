defmodule Health do
  @moduledoc """
  Monitors health of the rest of the OTP applications in the umbrella project
  """

  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Health.Worker.start_link(arg1, arg2, arg3)
      worker(Health.Checkers.State, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Health.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
