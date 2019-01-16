defimpl Plug.Exception, for: ApiAccounts.NoResultsError do
  def status(_expection), do: 404
end
