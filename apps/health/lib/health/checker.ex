defmodule Health.Checker do
  @moduledoc """
  Aggregator for multiple health checks.

  We can return both data about the checks (current/0) as well as a boolean
  as to whether we're healthy or not (healthy?/0).
  """
  @checkers Application.get_env(:health, :checkers)

  def current do
    :current
    |> each_checker
    |> Enum.reduce([], &Keyword.merge/2)
  end

  def healthy? do
    :healthy?
    |> each_checker
    |> Enum.all?()
  end

  defp each_checker(fun_name) do
    for checker <- @checkers do
      apply(checker, fun_name, [])
    end
  end
end
