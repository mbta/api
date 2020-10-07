defmodule SecretsProviderTest do
  use ExUnit.Case

  @opts [ex_aws: __MODULE__.FakeExAws]

  describe "load/2" do
    test "does nothing if AWS_SECRET_PREFIX is unset" do
      System.delete_env("AWS_SECRET_PREFIX")
      assert SecretsProvider.load([], :ok, @opts) == []
    end

    @tag :capture_log
    test "does nothing if we can't load AWS secrets" do
      System.put_env("AWS_SECRET_PREFIX", "invalid_prefix")
      assert SecretsProvider.load([], :ok, @opts) == []
    end

    test "loads secrets from SecretsManager" do
      System.put_env("AWS_SECRET_PREFIX", "prefix")

      assert SecretsProvider.load([], :ok, @opts) == [
               api_web: [
                 {ApiWeb.Endpoint,
                  [
                    secret_key_base: "secret-key-base"
                  ]},
                 signing_salt: "signing-salt"
               ]
             ]
    end
  end

  defmodule FakeExAws do
    def request(request) do
      case request.data do
        %{"SecretId" => "prefix-" <> value} ->
          {:ok, %{"SecretString" => value}}

        _ ->
          :error
      end
    end
  end
end
