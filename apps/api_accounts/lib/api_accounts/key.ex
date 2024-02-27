defmodule ApiAccounts.Key do
  @moduledoc """
  Representation of an API key belonging to a User.
  """
  use ApiAccounts.Table
  import ApiAccounts.Changeset

  @typedoc """
  Primary key for `ApiAccounts.Key.t`
  """
  @type key :: String.t()

  table "api_accounts_keys" do
    field(:key, :string, primary_key: true)
    field(:user_id, :string, secondary_index: true)
    field(:description, :string, default: nil)
    field(:created, :datetime)
    field(:requested_date, :datetime)
    field(:approved, :boolean, default: false)
    field(:locked, :boolean, default: false)
    field(:static_concurrent_limit, :integer)
    field(:streaming_concurrent_limit, :integer)
    field(:daily_limit, :integer)
    field(:rate_request_pending, :boolean, default: false)
    field(:api_version, :string)
    field(:allowed_domains, :string, default: "*")
    schema_version(3)
  end

  @doc false
  def changeset(struct, params \\ %{}) do
    fields = ~w(
      created requested_date approved locked static_concurrent_limit streaming_concurrent_limit daily_limit rate_request_pending api_version description allowed_domains
    )a
    cast(struct, params, fields)
  end
end
