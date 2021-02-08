defmodule Health.Checkers.Ports do
  @moduledoc """
  Health check which makes sure there are not too many ports open.
  """

  defp port_count do
    length(:erlang.ports())
  end

  def current do
    [ports: port_count()]
  end

  def healthy? do
    port_count() < Application.get_env(:health, __MODULE__)[:max_ports]
  end
end
