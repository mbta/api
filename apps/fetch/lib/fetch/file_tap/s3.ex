defmodule Fetch.FileTap.S3 do
  @moduledoc "FileTap which uploads the files to an S3 bucket"
  @default_opts [ex_aws_module: ExAws]

  def log_body(url, body, fetch_dt, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)

    with {:ok, name} <- bucket() do
      request = request(name, url, body, fetch_dt)
      opts[:ex_aws_module].request!(request)
    end
  end

  defp request(bucket_name, url, body, fetch_dt) do
    ExAws.S3.put_object(
      bucket_name,
      bucket_path(url, fetch_dt),
      :zlib.gzip(body),
      content_encoding: "gzip"
    )
  end

  defp bucket_path(url, fetch_dt) do
    prefix = Timex.format!(fetch_dt, "{YYYY}/{0M}/{0D}/{ISOdate}T{ISOtime}_")
    prefix <> escape_characters(url)
  end

  defp escape_characters(url) do
    # replace anything that's not a letter, number, or period with "_"
    String.replace(url, ~r/[^.[:alnum:]]/i, "_")
  end

  defp bucket do
    case Application.get_env(:fetch, FileTap.S3)[:bucket] do
      {:system, envvar} ->
        if value = System.get_env(envvar) do
          {:ok, value}
        else
          :error
        end

      value when is_binary(value) ->
        {:ok, value}

      _ ->
        :error
    end
  end
end
