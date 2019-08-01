defmodule State.Server.QueryTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule Example do
    @moduledoc false
    use Recordable, [:id, :data, :other_key]
    @opaque t :: %Example{}
  end

  defmodule Server do
    @moduledoc false
    use State.Server,
      indices: [:id, :other_key],
      recordable: State.Server.QueryTest.Example
  end

  alias State.Server.QueryTest.{Example, Server}
  import State.Server.Query

  doctest State.Server.Query

  describe "query/2" do
    setup :start_server

    test "returns all items without a query" do
      Server.new_state([%Example{}])
      assert query(Server, %{}) == [%Example{}]
    end

    test "given a query on the index, returns that item" do
      items = gen_items(2)
      Server.new_state(items)

      assert [%Example{id: 1}] = query(Server, %{id: [1]})
      assert [%Example{id: 1}] = query(Server, %{id: [0, 1]})
      assert [] = query(Server, %{id: [0]})
    end
  end

  defp start_server(_) do
    Server.start_link()
    Server.new_state([])

    on_exit(fn ->
      try do
        GenServer.stop(Server, :normal, 5_000)
      catch
        :exit, _ -> :ok
      end
    end)

    :ok
  end

  defp gen_items(count) do
    for i <- 1..count do
      %Example{id: i, data: i}
    end
  end
end
