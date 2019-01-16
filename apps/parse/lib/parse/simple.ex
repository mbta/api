defmodule Parse.Simple do
  @moduledoc """
  Simple CSV parser that only needs to define `parse_row(row)`.

      defmodule Parse.Thing do
        use Parse.Simple

        def parse_row(row) do
          ...
        end
      end

  """

  @callback parse_row(%{String.t() => String.t()}) :: any

  defmacro __using__([]) do
    quote location: :keep do
      import :binary, only: [copy: 1]
      @behaviour Parse
      @behaviour unquote(__MODULE__)

      @spec parse(String.t()) :: [any]
      def parse(blob) do
        unquote(__MODULE__).parse(blob, &parse_row/1)
      end
    end
  end

  @spec parse(String.t(), (map -> any)) :: [map]
  def parse(blob, row_callback)

  def parse("", _) do
    []
  end

  def parse(blob, row_callback) do
    blob
    |> ExCsv.parse!(headings: true)
    |> Enum.map(row_callback)
  end
end
