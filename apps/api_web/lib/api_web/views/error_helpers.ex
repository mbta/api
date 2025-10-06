defmodule ApiWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """
  use PhoenixHTML4Compat

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, _opts}) do
    msg
  end

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field, humanized \\ nil) do
    Enum.map(Map.get(form.source.errors, field, []), fn error ->
      humanized_field = humanized || Phoenix.Naming.humanize(field)
      translated_error = translate_error({error, []})
      error_message = "#{humanized_field} #{translated_error}."
      content_tag(:span, error_message, class: "help-block")
    end)
  end
end
