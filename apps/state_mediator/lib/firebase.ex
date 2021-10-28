defmodule StateMediator.Firebase do
  @moduledoc """
  Use `goth` to fetch Firebase oauth tokens to construct a URL.
  """

  @spec url(module(), String.t()) :: String.t()
  def url(goth_mod, base_url) do
    {:ok, goth_token} = Goth.fetch(goth_mod)
    base_url <> "?access_token=" <> goth_token.token
  end
end
