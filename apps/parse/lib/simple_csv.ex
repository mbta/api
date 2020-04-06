defmodule SimpleCSV do
  @moduledoc """
  A simpler, but higher-performance, CSV parser.  Expects that that lines being
  parsed don't contain any commas or quotes inside quoted fields.
  """

  @doc """
  Decodes the array of lines into an array of maps. The first row is
  expected to be the header names.
  """
  def decode(lines) do
    lines
    |> stream
    |> Enum.to_list()
  end

  @doc """
  Decodes a stream of lines into a stream of maps. The first row is
  expected to be the header names.
  """
  def stream(lines) do
    comma = :binary.compile_pattern(",")

    [headers] =
      lines
      |> Stream.take(1)
      |> Enum.map(&row_split(&1, comma))

    lines
    |> Stream.drop(1)
    |> Stream.map(&row_into_map(&1, headers, comma))
  end

  defp row_into_map(row, headers, comma) do
    row
    |> row_split(comma)
    |> split_into_map(headers)
  end

  defp split_into_map(split, headers) do
    headers
    |> Enum.zip(split)
    |> Map.new()
  end

  defp row_split(row, comma) do
    row
    |> :binary.split(comma, [:global])
    |> Enum.map(&binary_strip/1)
  end

  # assumes that a binary starting with " also ends with ", but doesn't check
  defp binary_strip(<<?", rest::binary>>) do
    rest_length = byte_size(rest)
    :binary.part(rest, {0, rest_length - 1})
  end

  defp binary_strip(binary), do: binary
end

defmodule BinaryLineSplit do
  @moduledoc """
  Higher-throughput line-based streaming.
  """
  @sep ["\r\n", "\n"]

  @doc """
  Streams lines out of a binary
  """
  def stream!(binary) when is_binary(binary) do
    binary
    |> Stream.unfold(&unfold(&1, :binary.compile_pattern(@sep)))
  end

  defp unfold("", _), do: nil

  defp unfold(acc, sep) do
    case :binary.split(acc, sep, [:trim]) do
      [first, rest] -> {first, rest}
      [first] -> {first, ""}
      [] -> nil
    end
  end
end
