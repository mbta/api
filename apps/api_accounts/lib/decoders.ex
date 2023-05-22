defimpl ExAws.Dynamo.Decodable, for: ApiAccounts.User do
  def decode(%ApiAccounts.User{join_date: nil} = user), do: user

  def decode(%ApiAccounts.User{join_date: join_date, totp_since: totp_since} = user) do
    join_date = Decoders.datetime(join_date)
    totp_since = Decoders.datetime(totp_since)
    totp_binary = if user.totp_secret, do: Base.decode32!(user.totp_secret)

    %ApiAccounts.User{
      user
      | join_date: join_date,
        totp_since: totp_since,
        totp_secret_bin: totp_binary
    }
  end
end

defimpl ExAws.Dynamo.Decodable, for: ApiAccounts.Key do
  def decode(%ApiAccounts.Key{} = key) do
    created =
      if key.created do
        Decoders.datetime(key.created)
      end

    requested_date =
      if key.requested_date do
        Decoders.datetime(key.requested_date)
      end

    %ApiAccounts.Key{key | created: created, requested_date: requested_date}
  end
end

defmodule Decoders do
  @moduledoc false
  def datetime(nil), do: nil

  def datetime(datetime_string) do
    if String.ends_with?(datetime_string, "Z") do
      {:ok, datetime, _} = DateTime.from_iso8601(datetime_string)
      datetime
    else
      NaiveDateTime.from_iso8601!(datetime_string)
    end
  end
end
