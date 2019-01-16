defmodule RecordableTest do
  use ExUnit.Case, async: true

  defmodule Example do
    use Recordable, [:key, :val]
  end

  defmodule ExampleWithPairs do
    use Recordable, key: :key, val: :val
  end

  alias RecordableTest.{Example, ExampleWithPairs}

  test "to_record/1" do
    assert Example.to_record(%Example{key: :key, val: :val}) == {Example, :key, :val}

    assert ExampleWithPairs.to_record(%ExampleWithPairs{key: :other}) ==
             {ExampleWithPairs, :other, :val}
  end

  test "from_record/1" do
    assert Example.from_record({Example, :key, :val}) == %Example{key: :key, val: :val}

    assert ExampleWithPairs.from_record({ExampleWithPairs, :key, :val}) == %ExampleWithPairs{
             key: :key,
             val: :val
           }
  end

  test "fields/0" do
    assert Example.fields() == [:key, :val]
    assert ExampleWithPairs.fields() == [:key, :val]
  end
end
