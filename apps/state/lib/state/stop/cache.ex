defmodule State.Stop.Cache do
  @moduledoc """
  Caches `Model.Stop.t` by `Model.Stop.id` and `Model.Stop.t` `parent_station`
  """

  use State.Server,
    indicies: [:id, :parent_station, :location_type],
    recordable: Model.Stop

  def by_id(id) do
    case super(id) do
      [] -> nil
      [stop] -> stop
    end
  end
end
