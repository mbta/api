defmodule Model.Line do
  @moduledoc """
  Line is a combination of existing routes in routes.txt.
  """

  use Recordable, [
    :id,
    :short_name,
    :long_name,
    :description,
    :sort_order,
    color: "FFFFFF",
    text_color: "000000"
  ]

  @typedoc """
  The color must be be a six-character hexadecimal number, for example, `00FFFF`. If no color is specified, the default
  route color is white (`FFFFFF`).
  """
  @type color :: String.t()
  @type id :: String.t()

  @typedoc """
  * `:id` - Unique line ID
  * `:short_name` - Short, public-facing name for the group of routes represented in this line
  * `:long_name` - Lengthier, public-facing name for the group of routes represented in this line
  * `:description` - Contains a human-readable description of the line
  * `:color` - In systems that have colors assigned to lines, the route_color field defines a color 
      that corresponds to a line. The color must be provided as a six-character hexadecimal number, 
      for example, `00FFFF`. If no color is specified, the default route color is white (`FFFFFF`).
  * `:text_color` - This field can be used to specify a legible color to use for text drawn against 
      a background of line_color. The color must be provided as a six-character hexadecimal number, 
      for example, `FFD700`. If no color is specified, the default text color is black (`000000`).
  * `:sort_order` - Can be used to order the lines in a way which is ideal for presentation to customers. 
      It must be a non-negative integer. 
  """
  @type t :: %__MODULE__{
          id: id,
          short_name: String.t() | nil,
          long_name: String.t() | nil,
          description: String.t() | nil,
          color: color,
          text_color: color,
          sort_order: non_neg_integer
        }
end
