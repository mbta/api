defmodule Recordable do
  @moduledoc """
  Converts a `struct` to a record that can be stores in ETS and mnesia and back out again.
  """

  defmacro recordable(opts) do
    keys_or_kvs = Macro.expand(opts, __CALLER__)

    keys =
      for key_or_kv <- keys_or_kvs do
        case key_or_kv do
          {key, _} -> key
          key -> key
        end
      end

    vals = Enum.map(keys, &{&1, [], nil})
    pairs = Enum.zip(keys, vals)

    # create a pairs object with each value being the filler variable
    fill_pairs = Enum.zip(keys, Stream.cycle([:_]))

    quote do
      require Record

      defstruct unquote(keys_or_kvs)
      Record.defrecord(__MODULE__, [unquote_splicing(keys)])

      def to_record(%__MODULE__{unquote_splicing(pairs)}) do
        {__MODULE__, unquote_splicing(vals)}
      end

      def from_record({__MODULE__, unquote_splicing(vals)}) do
        %__MODULE__{unquote_splicing(pairs)}
      end

      def to_list(%__MODULE__{unquote_splicing(pairs)}) do
        [unquote_splicing(vals)]
      end

      def from_list([unquote_splicing(vals)]) do
        %__MODULE__{unquote_splicing(pairs)}
      end

      def fields, do: unquote(keys)

      def filled(_) do
        %__MODULE__{unquote_splicing(fill_pairs)}
      end
    end
  end

  defmacro __using__(keys) do
    quote do
      require unquote(__MODULE__)
      unquote(__MODULE__).recordable(unquote(keys))
    end
  end
end
