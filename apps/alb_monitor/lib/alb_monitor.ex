defmodule ALBMonitor do
  @moduledoc """
  When the app is running on AWS, monitors the Application Load Balancer for the instance and
  proactively shuts down the app when it begins draining connections, to ensure long-lived event
  stream connections are cleanly closed.
  """

  use Application

  def start(_type, _args) do
    children = [
      ALBMonitor.Monitor
    ]

    opts = [strategy: :one_for_one, name: ALBMonitor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
