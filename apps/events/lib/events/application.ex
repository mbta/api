defmodule Events.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :duplicate, name: Events.Registry}
    ]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: Events.Supervisor
    )
  end
end
