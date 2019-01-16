defmodule Parse.Realtime do
  @moduledoc """
  Parses GTFS realtime protocol
  """

  use Protobuf, from: Path.expand("../../gtfs-realtime.proto", __DIR__)
end
