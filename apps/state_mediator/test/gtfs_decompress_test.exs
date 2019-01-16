defmodule GtfsDecompressTest do
  @moduledoc false
  use ExUnit.Case

  setup_all _ do
    Application.stop(:state)

    on_exit(fn ->
      Application.ensure_all_started(:state)
    end)
  end

  describe "new_state/1" do
    setup _ do
      expected_receives =
        for filename <- GtfsDecompress.filenames(),
            event_name = {:fetch, filename},
            ref = make_ref() do
          Events.subscribe(event_name, ref)
          {:event, event_name, body(filename), ref}
        end

      {:ok, %{expected_receives: expected_receives}}
    end

    test "triggers an event for each filename", %{expected_receives: expected_receives} do
      GtfsDecompress.filenames()
      |> build_zip
      |> GtfsDecompress.new_state()

      for expected_receive <- expected_receives do
        assert_receive ^expected_receive
      end
    end

    test "crashes if a file is missing from the ZIP file", %{expected_receives: expected_receives} do
      keeping = Enum.take(GtfsDecompress.filenames(), 5)
      {_expected_receives, unexpected_receives} = Enum.split(expected_receives, 5)

      assert_raise MatchError, fn ->
        keeping
        |> build_zip
        |> GtfsDecompress.new_state()
      end

      for unexpected_receive <- unexpected_receives do
        refute_receive ^unexpected_receive
      end
    end
  end

  defp build_zip(filenames) do
    file_list =
      for filename <- filenames do
        {to_charlist(filename), body(filename)}
      end

    {:ok, {_, body}} = :zip.create('GTFS.zip', file_list, [:memory])
    body
  end

  defp body(filename), do: "#{filename} body"
end
