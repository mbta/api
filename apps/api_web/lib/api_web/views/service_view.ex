defmodule ApiWeb.ServiceView do
  use ApiWeb.Web, :api_view

  location("/services/:id")

  attributes([
    :start_date,
    :end_date,
    :valid_days,
    :description,
    :schedule_name,
    :schedule_type,
    :schedule_typicality,
    :added_dates,
    :added_dates_notes,
    :removed_dates,
    :removed_dates_notes
  ])
end
