defimpl ExAws.Dynamo.Encodable, for: NaiveDateTime do
  def encode(datetime, _) do
    %{"S" => NaiveDateTime.to_iso8601(datetime)}
  end
end

defimpl ExAws.Dynamo.Encodable, for: DateTime do
  def encode(datetime, _) do
    %{"S" => DateTime.to_iso8601(datetime)}
  end
end
