defmodule PhoenixHTML4Compat do
  @moduledoc """
  Replace `use Phoenix.HTML` with `use PhoenixHTML4Compat` for compatibility
  with phoenix_html 4.0+.

  https://hexdocs.pm/phoenix_html/changelog.html#v4-0-0-2023-12-19
  """
  defmacro __using__(_) do
    import Phoenix.HTML
    import Phoenix.HTML.Form
    use PhoenixHTMLHelpers
  end
end
