defmodule Fetch.FileTap.S3Test do
  @moduledoc false
  use ExUnit.Case, async: true
  import Fetch.FileTap.S3

  defmodule MockAws do
    @moduledoc "Make a fake request to AWS"
    def request!(request) do
      {:ok, request}
    end
  end

  @url "http://fetch.test/example.pb"
  @now ~N[2017-05-12T14:53:21]
  @opts [ex_aws_module: __MODULE__.MockAws]
  @body String.duplicate("body", 100)

  describe "log_body/3" do
    setup [:set_bucket_name]

    test "uploads gzipped contents to S3" do
      assert {:ok, request} = log_body(@url, @body, @now, @opts)
      assert request.http_method == :put
      assert request.bucket == "test-bucket"
      assert request.path == "2017/05/12/2017-05-12T14:53:21_http___fetch.test_example.pb"
      assert :zlib.gunzip(request.body) == @body
      assert byte_size(request.body) < byte_size(@body)
    end
  end

  describe "log_body/3 without setup" do
    test "returns an error" do
      assert :error = log_body(@url, @body, @now, @opts)
    end
  end

  defp set_bucket_name(context) do
    old_config = Application.get_env(:fetch, FileTap.S3)

    on_exit(fn ->
      Application.put_env(:fetch, FileTap.S3, old_config)
    end)

    Application.put_env(:fetch, FileTap.S3, bucket: "test-bucket")
    {:ok, context}
  end
end
