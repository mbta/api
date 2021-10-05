defmodule ConfigProviders.SecretsManagerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias ConfigProviders.SecretsManager

  @opts [ex_aws: __MODULE__.FakeExAws]

  describe "load/2" do
    test "won't continue if AWS_SECRET_PREFIX is unset" do
      System.delete_env("AWS_SECRET_PREFIX")
      assert_raise(FunctionClauseError, fn -> SecretsManager.load([], :ok, @opts) end)
    end

    test "won't continue if can't load AWS secrets" do
      System.put_env("AWS_SECRET_PREFIX", "invalid_prefix")

      log =
        capture_log(fn ->
          assert_raise(MatchError, fn -> SecretsManager.load([], :ok, @opts) end)
        end)

      assert log =~ "unable_to_fetch_secret"
    end

    test "loads secrets from SecretsManager" do
      System.put_env("AWS_SECRET_PREFIX", "prefix")

      assert SecretsManager.load([], :ok, @opts) == [
               api_web: [
                 {ApiWeb.Endpoint,
                  [
                    secret_key_base: "secret-key-base"
                  ]},
                 {:signing_salt, "signing-salt"}
               ],
               state_mediator: [
                 {:commuter_rail_crowding,
                  [firebase_credentials: "cr-crowding-firebase-credentials"]}
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
