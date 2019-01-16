defmodule Model.Direction do
  shared_doc = """
  The direction ID (`0` and `1`) used by
  [GTFS `trips.txt`](https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md#tripstxt) has no defined
  human-readable interpretation: it depends on each route in MBTA's system.
  """

  @moduledoc shared_doc

  @typedoc shared_doc
  @type id :: 0 | 1
end
