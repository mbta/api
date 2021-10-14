defmodule ConfigProviders.SecretsManager do
  @moduledoc """
  Config.Provider implementation for fetching data from AWS Secrets Manager
  """
  @behaviour Config.Provider

  require Logger

  @application_requirements [
    :ex_aws_secretsmanager,
    :hackney
  ]

  @type config :: Config.Provider.config()

  @impl Config.Provider
  def init(_), do: :ok

  @impl Config.Provider
  def load(config, _, opts \\ []) do
    prefix = System.get_env("AWS_SECRET_PREFIX")
    load_prefix(config, prefix, opts)
  end

  @spec load_prefix(config(), String.t(), Keyword.t()) :: config()
  defp load_prefix(config, prefix, opts) when is_binary(prefix) do
    config
    |> update_config(
      prefix <> "-secret-key-base",
      fn value ->
        [
          api_web: [
            {ApiWeb.Endpoint, [secret_key_base: value]}
          ]
        ]
      end,
      opts
    )
    |> update_config(
      prefix <> "-signing-salt",
      fn value ->
        [
          api_web: [
            signing_salt: value
          ]
        ]
      end,
      opts
    )
  end

  @spec secret_string(binary, Keyword.t()) :: {:ok, binary} | :error
  defp secret_string(secret_name, opts) when is_binary(secret_name) do
    ensure_all_started!()
    ex_aws = Keyword.get(opts, :ex_aws, ExAws)
    request = ExAws.SecretsManager.get_secret_value(secret_name)

    case ex_aws.request(request) do
      {:ok, %{"SecretString" => secret}} ->
        {:ok, secret}

      e ->
        Logger.error("unable_to_fetch_secret e=#{inspect(e)} name=#{inspect(secret_name)}")
        :error
    end
  end

  @spec update_config(config(), binary(), (binary() -> config()), Keyword.t()) :: config()
  defp update_config(config, secret_name, fun, opts)
       when is_binary(secret_name) and is_function(fun, 1) do
    {:ok, value} = secret_string(secret_name, opts)
    Config.Reader.merge(config, fun.(value))
  end

  defp ensure_all_started! do
    for app <- @application_requirements do
      {:ok, _} = Application.ensure_all_started(app)
    end

    :ok
  end
end
