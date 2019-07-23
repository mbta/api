defmodule State.ServerTest do
  use ExUnit.Case, async: true

  defmodule Example do
    use Recordable, [:id, :data, :other_key]
    @opaque t :: %Example{}
  end

  defmodule Parser do
    def parse("") do
      [%Example{id: "binary"}]
    end
  end

  defmodule Server do
    use State.Server,
      indices: [:id, :other_key],
      parser: State.ServerTest.Parser,
      recordable: State.ServerTest.Example
  end

  alias State.ServerTest.{Example, Server}

  setup do
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

  describe "generated server" do
    test "size/0 returns the size" do
      assert Server.size() == 0
      Server.new_state([%Example{}])
      assert Server.size() == 1
    end

    test "all/0 returns all elements" do
      assert Server.all() == []
      Server.new_state([%Example{}])
      assert Server.all() == [%Example{}]
    end

    test "all_keys/0 returns the keys" do
      assert Server.all_keys() == []
      Server.new_state([%Example{id: "id"}])
      assert Server.all_keys() == ["id"]
    end

    test "by_id/1 returns a list of elements" do
      assert Server.by_id(nil) == []
      assert Server.by_id(1) == []
      assert Server.by_ids([nil, 1]) == []
      Server.new_state([%Example{}])
      assert Server.by_id(nil) == [%Example{}]
      assert Server.by_id(1) == []
      assert Server.by_ids([nil, 1]) == [%Example{}]
    end

    test "by_id/1 returns items in the order they were given" do
      one = %Example{id: 1}
      two = %Example{id: 2}
      Server.new_state([one, two])

      assert Server.by_ids([1, 2]) == [one, two]
      assert Server.by_ids([2, 1]) == [two, one]
    end

    test "maintains different indexes" do
      value = %Example{id: :id, other_key: :other}
      Server.new_state([value])
      assert Server.by_id(:id) == [value]
      assert Server.by_id(:other) == []
      assert Server.by_other_key(:id) == []
      assert Server.by_other_key(:other) == [value]
    end

    test "match returns items which match additional values" do
      value = %Example{id: :id, data: :data}
      Server.new_state([value])

      for id <- [nil, :id],
          data <- [nil, :data] do
        expected =
          if {id, data} == {:id, :data} do
            [value]
          else
            []
          end

        actual = Server.match(%{id: id, data: data}, :id)
        assert actual == expected
      end
    end

    test "select does multiple matches" do
      values = [
        %Example{id: :id, data: :data},
        %Example{id: :other, data: :data}
      ]

      Server.new_state(values)
      matchers = [%{id: :id}, %{id: :other}]
      assert matchers |> Server.select() |> Enum.sort() == values
      assert matchers |> Server.select(:id) |> Enum.sort() == values
    end

    test "select_limit can limit the returned data" do
      values = [
        %Example{id: :id, data: :data},
        %Example{id: :other, data: :data}
      ]

      Server.new_state(values)

      assert [_] = Server.select_limit([%{data: :data}], 1)
      assert [] = Server.select_limit([%{data: :no_data}], 1)
    end

    test "new_state overwrites a previous state" do
      Server.new_state([%Example{id: 1}])
      Server.new_state([])
      assert Server.by_id(1) == []
    end

    @tag :capture_log
    test "can take a binary and parse it" do
      Server.new_state("")
      assert Server.by_id("binary") != []

      # doesn't clear the old state
      Server.new_state("invalid")
      assert Server.by_id("binary") != []
    end

    test "new_state does not show an empty state" do
      value = %Example{id: 1, data: 1}
      Server.new_state([value])
      assert Server.by_id(1) == [value]

      task =
        Task.async(fn ->
          [value]
          |> Stream.cycle()
          |> Server.new_state(:infinity)
        end)

      for _i <- Range.new(0, 1_000) do
        assert Server.by_id(1) != []
      end

      # wait for everything to shut down
      Task.shutdown(task, :brutal_kill)
      Process.flag(:trap_exit, true)
      example_pid = GenServer.whereis(Server)

      case example_pid do
        nil ->
          :ok

        pid ->
          Process.exit(pid, :brutal_kill)

          receive do
            {:EXIT, ^pid, :brutal_kill} -> :ok
          end
      end

      Process.flag(:trap_exit, false)
    end
  end

  describe "events" do
    test "new_state emits an event with the size" do
      Events.subscribe({:new_state, Server})
      Server.new_state([%Example{id: 1}])
      assert_received {:event, {:new_state, Server}, 1, nil}
    end

    test "emits an 0 size event on startup" do
      GenServer.stop(Server)
      Events.subscribe({:new_state, Server})
      Server.start_link()
      assert_received {:event, {:new_state, Server}, 0, nil}
    end
  end

  describe "shutdown/2" do
    test "deletes mnesia table" do
      :ok = :mnesia.wait_for_tables([Server], 0)
      State.Server.shutdown(Server, :testing)

      assert {:timeout, [Server]} = :mnesia.wait_for_tables([Server], 0)
    end
  end
end
