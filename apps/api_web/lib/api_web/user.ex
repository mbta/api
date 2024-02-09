defmodule ApiWeb.User do
  @moduledoc """
  Struct for respresenting a user during a request.
  """

  @default_version Application.compile_env(:api_web, :versions)[:default]

  defstruct [
    :id,
    :type,
    :limit,
    :version,
    :allowed_domains
  ]

  @typedoc """
  The anonymous user's IP Address

  1. `String.t` - the `X-Forwarded-For` header
  2. `:inet.ip_address` - the IP address of the `Plug.Conn.t`
  """
  @type anon_id :: :inet.ip_address() | String.t()

  @typedoc """
  The default version for the given key.
  """
  @type version :: String.t()

  @typedoc """
  The list of domains to match for the access-control-allow-origin header
  """
  @type allowed_domains :: String.t()

  @typedoc """
  The max number of requests per day that the user can make.
  """
  @type requests_per_day :: integer

  @typedoc """
  Whether the user is an anonymous user or a registered user.

  * `:anon` - An anonymous user that is tracked by IP address
  * `:registered` - The user registered for an API key and are tracked by `id`.

  """
  @type type :: :registered | :anon

  @typedoc """
  There are two types of users `:anon` and `:registered`

  ## `:anon`

  * `:id` - The effective IP address
  * `:limit` - anonymous users cannot have a requests per day limit increase from the default
      (#{ApiWeb.RateLimiter.max_anon_per_interval() * ApiWeb.RateLimiter.intervals_per_day()}), which is indicated by `nil`.
  * `:type` - `:anon`

  ## `:registered`

  * `:id` - The API key used by the user for the API request
  * `:limit` - `nil` indicates the default, registered user limit
      (#{ApiWeb.RateLimiter.max_registered_per_interval() * ApiWeb.RateLimiter.intervals_per_day()}); `integer` is increased
      requests per day granted after the user requested an increase.
  * `:type` - `:registered`

  """
  @type t ::
          %__MODULE__{
            id: anon_id,
            version: version,
            limit: nil,
            type: :anon,
            allowed_domains: allowed_domains
          }
          | %__MODULE__{
              id: ApiAccounts.Key.key(),
              version: version,
              limit: requests_per_day | nil,
              type: :registered,
              allowed_domains: allowed_domains
            }

  @doc """
  Creates an anonymous user with a given identifier.

      iex> ApiWeb.User.anon("some_id")
      %ApiWeb.User{id: "some_id", type: :anon, limit: nil, version: "#{@default_version}", allowed_domains: "*"}

  """
  @spec anon(any) :: t
  def anon(id),
    do: %__MODULE__{id: id, type: :anon, version: @default_version, allowed_domains: "*"}

  @doc """
  Creates a user struct from a valid Key.

      iex(1)> key = %ApiAccounts.Key{key: "key", user_id: "1", daily_limit: 10, api_version: "2017-11-28"}
      iex(2)> ApiWeb.User.from_key(key)
      %ApiWeb.User{id: "key", limit: 10, type: :registered, version: "2017-11-28", allowed_domains: "*"}

  """
  @spec from_key(ApiAccounts.Key.t()) :: t
  def from_key(%ApiAccounts.Key{
        key: key,
        daily_limit: limit,
        api_version: version,
        allowed_domains: allowed_domains
      }) do
    version = version || @default_version

    %__MODULE__{
      id: key,
      limit: limit,
      type: :registered,
      version: version,
      allowed_domains: nil_or_allowed_domains(allowed_domains)
    }
  end

  defp nil_or_allowed_domains(nil), do: "*"
  defp nil_or_allowed_domains(allowed_domains), do: allowed_domains
end
