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

  def input_validations(%Changeset{} = changeset, _, field) do
    [required: field in changeset.required] ++
      for(
        {key, validation} <- changeset.validations,
        key == field,
        attr <- validation_to_attrs(validation, field, changeset),
        do: attr
      )
  end

  defp validation_to_attrs({:length, opts}, _field, _changeset) do
    max =
      if val = Keyword.get(opts, :max) do
        [maxlength: val]
      else
        []
      end

    min =
      if val = Keyword.get(opts, :min) do
        [minlength: val]
      else
        []
      end

    max ++ min
  end

  defp validation_to_attrs({:number, opts}, field, changeset) do
    type = Map.get(changeset.types, field, :integer)
    step_for(type) ++ min_for(type, opts) ++ max_for(type, opts)
  end

  defp validation_to_attrs(_validation, _field, _changeset) do
    []
  end

  defp step_for(:integer), do: [step: 1]
  defp step_for(_other), do: [step: "any"]

  defp max_for(type, opts) do
    cond do
      max = type == :integer && Keyword.get(opts, :less_than) ->
        [max: max - 1]

      max = Keyword.get(opts, :less_than_or_equal_to) ->
        [max: max]

      true ->
        []
    end
  end

  defp min_for(type, opts) do
    cond do
      min = type == :integer && Keyword.get(opts, :greater_than) ->
        [min: min + 1]

      min = Keyword.get(opts, :greater_than_or_equal_to) ->
        [min: min]

      true ->
        []
    end
  end

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
