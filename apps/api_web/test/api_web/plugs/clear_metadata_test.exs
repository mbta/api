defmodule ApiWeb.Plugs.ClearMetadataTest do
  @moduledoc false
  use ApiWeb.ConnCase
  alias ApiWeb.Plugs.ClearMetadata

  @opts ClearMetadata.init(~w(metadata_value)a)

  test "clears given metadata values", %{conn: conn} do
    Logger.metadata(metadata_value: :value)
    assert conn == ClearMetadata.call(conn, @opts)
    assert Logger.metadata() == []
  end

  test "does not clear metadata values not given", %{conn: conn} do
    Logger.metadata(metadata_keep: :value)
    assert conn == ClearMetadata.call(conn, @opts)
    assert Logger.metadata() == [metadata_keep: :value]
  end
end
