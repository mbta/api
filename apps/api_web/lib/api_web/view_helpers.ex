defmodule ApiWeb.ViewHelpers do
  @moduledoc """
  Shared functions for HTML views.
  """
  use Phoenix.Component

  @doc """
  Generates a form-group div for a field.

  If the field has an error, the appropriate error class is added to the
  form group div.
  """
  def form_group(%{form: form, field: field} = assigns) do
    if Map.get(form.source.errors, field, []) == [] do
      ~H"""
      <div class="form-group">
        {render_slot(@inner_block)}
      </div>
      """
    else
      ~H"""
      <div class="form-group has-error">
        {render_slot(@inner_block)}
      </div>
      """
    end
  end
end
