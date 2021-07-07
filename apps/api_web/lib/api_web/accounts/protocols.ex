defimpl Phoenix.Param, for: ApiAccounts.User do
  def to_param(%ApiAccounts.User{} = user) do
    ApiAccounts.User.pkey(user)
  end
end

defimpl Phoenix.Param, for: ApiAccounts.Key do
  def to_param(%ApiAccounts.Key{} = key) do
    ApiAccounts.Key.pkey(key)
  end
end

defimpl Phoenix.HTML.FormData, for: ApiAccounts.Changeset do
  alias ApiAccounts.Changeset

  def to_form(changeset, opts) do
    %{params: params, data: data} = changeset
    {name, opts} = Keyword.pop(opts, :as)
    name = to_string(name || form_for_name(data))

    %Phoenix.HTML.Form{
      source: changeset,
      impl: __MODULE__,
      id: name,
      name: name,
      errors: form_for_errors(changeset),
      data: data,
      params: params || %{},
      hidden: form_for_hidden(data),
      options: Keyword.put_new(opts, :method, form_for_method(data))
    }
  end

  def to_form(_data, _form, _field, _opts) do
    raise ArgumentError, "nested inputs are not supported"
  end

  def input_value(%{changes: changes, data: data}, %{params: params}, field, computed \\ nil) do
    case Map.fetch(changes, field) do
      {:ok, value} ->
        value

      :error ->
        case Map.fetch(params, Atom.to_string(field)) do
          {:ok, value} ->
            value

          :error when is_nil(computed) ->
            Map.get(data, field)

          :error ->
            computed
        end
    end
  end

  def input_type(%{types: types}, _, field) do
    type = Map.get(types, field, :string)
    do_input_type(type)
  end

  defp do_input_type(:integer), do: :number_input
  defp do_input_type(:float), do: :number_input
  defp do_input_type(:decimal), do: :number_input
  defp do_input_type(:boolean), do: :checkbox
  defp do_input_type(:date), do: :date_select
  defp do_input_type(:time), do: :time_select
  defp do_input_type(:utc_datetime), do: :datetime_select
  defp do_input_type(:naive_datetime), do: :datetime_select
  defp do_input_type(_), do: :text_input

  # Function necessary for protocol, but no validations for now.
  def input_validations(%Changeset{} = _changeset, _, _), do: []

  defp form_for_errors(%{action: nil}), do: []
  defp form_for_errors(%{errors: errors}), do: errors

  defp form_for_hidden(%{__struct__: module} = data) do
    module.__schema__(:primary_key)
  rescue
    _ -> []
  else
    keys -> for k <- keys, v = Map.fetch!(data, k), do: {k, v}
  end

  defp form_for_hidden(_), do: []

  defp form_for_name(%{__struct__: module}) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp form_for_name(_) do
    raise ArgumentError, "non-struct data in changeset requires the :as " <> "option to be given"
  end

  defp form_for_method(%{__meta__: %{state: :loaded}}), do: "put"
  defp form_for_method(_), do: "post"
end
