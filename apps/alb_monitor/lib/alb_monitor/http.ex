defmodule ALBMonitor.HTTP do
  @moduledoc """
  Minimal HTTP client for the ECS task metadata endpoint. A behaviour so tests can mock it.
  """

  @callback get(String.t()) :: {:ok, %{body: binary()}} | {:error, term()}

  @spec get(String.t()) :: {:ok, Req.Response.t()} | {:error, Exception.t()}
  def get(url) do
    # The monitor already retries on its next check, so Req shouldn't retry too.
    Req.get(url, decode_body: false, retry: false, receive_timeout: 5_000)
  end
end
