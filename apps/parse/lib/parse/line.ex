defmodule Parse.Line do
  @moduledoc """
  Parses `lines.txt` CSV from GTFS zip

    line_id,line_short_name,line_long_name,line_desc,line_url,line_color,line_text_color,line_sort_order
    line-Red,,Red Line,,,DA291C,FFFFFF,1
  """

  use Parse.Simple
  alias Model.Line

  @doc """
  Parses (non-header) row of `lines.txt`

  ## Columns

  * `"line_id"` - `Model.Line.t` `id`
  * `"line_short_name"` - `Model.Line.t` `short_name`
  * `"line_long_name"` - `Model.Line.t` `long_name`
  * `"line_desc"` - `Model.Line.t` `description`
  * `"line_color"` - `Model.Line.t` `color`
  * `"line_text_color"` - `Model.Line.t` `text_color`
  * `"line_sort_order"` - `Model.Line.t` `sort_order`

  """
  def parse_row(row) do
    %Line{
      id: copy(row["line_id"]),
      short_name: copy(row["line_short_name"]),
      long_name: copy(row["line_long_name"]),
      description: copy(row["line_desc"]),
      color: copy(row["line_color"]),
      text_color: copy(row["line_text_color"]),
      sort_order: String.to_integer(row["line_sort_order"])
    }
  end
end
