defmodule ApiWeb.Plugs.ModifiedSinceHandlerTest do
  use ApiWeb.ConnCase
  use ExUnitProperties
  alias ApiWeb.Plugs.ModifiedSinceHandler

  defmodule Resource do
    def state_module, do: __MODULE__
  end

  @datetime "Wed, 21 Oct 2015 07:28:00 GMT"

  describe "init/1" do
    test "raises when :state_module not provided" do
      assert_raise ArgumentError, fn ->
        ModifiedSinceHandler.init([])
      end
    end

    test "gives opts" do
      opts = [caller: Resource]
      assert ModifiedSinceHandler.init(opts) == opts
    end
  end

  describe "call/2" do
    setup %{conn: conn} do
      opts = [caller: Resource]

      {:ok, conn: conn, opts: opts}
    end

    test "does nothing when no header present", %{conn: conn, opts: opts} do
      conn = ModifiedSinceHandler.call(conn, opts)
      refute conn.halted
      refute conn.status
      refute conn.state == :sent
    end

    test "ignores invalid values for header", %{conn: conn, opts: opts} do
      conn =
        conn
        |> Plug.Conn.put_req_header("if-modified-since", "2015-10-21T07:28:00Z")
        |> ModifiedSinceHandler.call(opts)

      refute conn.halted
      refute conn.status
      refute conn.state == :sent
    end

    test "returns 304 with unmodified resource", %{conn: conn, opts: opts} do
      updated = DateTime.from_naive!(~N[2015-10-21 07:28:00], "Etc/UTC")
      State.Metadata.state_updated(Resource, updated)

      conn =
        conn
        |> Plug.Conn.put_req_header("if-modified-since", @datetime)
        |> bypass_through()
        |> get("/")
        |> ModifiedSinceHandler.call(opts)

      assert conn.status == 304
      assert conn.halted
      assert conn.state == :sent
    end

    test "continutes with modified resource", %{conn: conn, opts: opts} do
      State.Metadata.state_updated(Resource, DateTime.utc_now())

      conn =
        conn
        |> Plug.Conn.put_req_header("if-modified-since", @datetime)
        |> ModifiedSinceHandler.call(opts)

      refute conn.status
      refute conn.halted
      refute conn.state == :sent
      assert [_] = Plug.Conn.get_resp_header(conn, "last-modified")
    end
  end

  describe "is_modified?/2" do
    property "is true when first header is greater than second header" do
      check all(
              {first, first_header} <- rfc1123(),
              {second, second_header} <- rfc1123(),
              max_runs: 1000
            ) do
        expected = first > second
        actual = ModifiedSinceHandler.is_modified?(first_header, second_header)
        assert expected == actual
      end
    end

    defp rfc1123 do
      gen all(base_timestamp <- integer()) do
        timestamp = base_timestamp * 10_000
        {:ok, datetime} = DateTime.from_unix(timestamp)
        {:ok, <<rendered::binary-26, "Z">>} = Timex.format(datetime, "{RFC1123z}")
        {timestamp, rendered <> "GMT"}
      end
    end
  end
end
