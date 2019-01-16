defmodule ApiWeb.Admin.Accounts.UserView do
  use ApiWeb.Web, :view

  @doc """
  Gets a pending key request if one is present.
  """
  @spec key_request([ApiAccounts.Key.t()]) :: ApiAccounts.Key.t() | nil
  def key_request(keys) do
    Enum.find(keys, &(not &1.approved))
  end
end
