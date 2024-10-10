defmodule Parse.Agency do
  @moduledoc """
  Parses `agency.txt` CSV from GTFS zip

    agency_id,agency_name,agency_url,agency_timezone,agency_lang,agency_phone
    1,MBTA,http://www.mbta.com,America/New_York,EN,617-222-3200
  """

  use Parse.Simple
  alias Model.Agency

  @doc """
  Parses (non-header) row of `agency.txt`

  ## Columns

  * `"agency_id"` - `Model.Agency.t` - `id`
  * `"agency_name"` - `Model.Agency.t` - `agency_name`
  """
  def parse_row(row) do
    %Agency{
      id: copy(row["agency_id"]),
      agency_name: copy(row["agency_name"])
    }
  end
end
