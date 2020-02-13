defimpl Plug.Exception, for: ApiAccounts.NoResultsError do
  def status(_expection), do: 404

  def actions(_exception), do: []
end
