defmodule ApiWeb.LegacyStops do
  @moduledoc """
  Enables backwards compatibility for changes to stop IDs and "splitting" of stops, e.g. from a
  station having one non-platform-specific child stop to having a child stop for each platform.

  Mappings from old to new stop IDs are expressed as:

    %{"2020-01-01" => %{"old_id" => {"new_id", ["new_1", "new_2"]}}}

  In this example, stop `old_id` was renamed to `new_id` and two sibling stops were added (if no
  rename or additions occurred, these elements would be `nil` and `[]` respectively). Requests
  using API versions earlier than 2020-01-01 that use `old_id` in a stop ID filter should behave
  as though `new_id`, `new_1`, and `new_2` were *also* specified. Renames are distinguished from
  additions so that only renames can be considered when a request is for a single stop.

  An "old" ID may appear in multiple versions. Chained mappings where one version's "new" ID is a
  later version's "old" ID are also possible.
  """

  alias Model.Stop

  @mappings %{
    "2018-07-23" => %{
      "Back Bay" =>
        {nil, ["Back Bay-01", "Back Bay-02", "Back Bay-03", "Back Bay-05", "Back Bay-07"]},
      "North Station" =>
        {nil,
         [
           "North Station-01",
           "North Station-02",
           "North Station-03",
           "North Station-04",
           "North Station-05",
           "North Station-06",
           "North Station-07",
           "North Station-08",
           "North Station-09",
           "North Station-10"
         ]},
      "South Station" =>
        {nil,
         [
           "South Station-01",
           "South Station-02",
           "South Station-03",
           "South Station-04",
           "South Station-05",
           "South Station-06",
           "South Station-07",
           "South Station-08",
           "South Station-09",
           "South Station-10",
           "South Station-11",
           "South Station-12",
           "South Station-13"
         ]}
    },
    "2019-02-12" => %{
      "70001" => {nil, ["Forest Hills-01", "Forest Hills-02"]},
      "70036" => {nil, ["Oak Grove-01", "Oak Grove-02"]},
      "70061" => {nil, ["Alewife-01", "Alewife-02"]},
      "70105" => {nil, ["Braintree-01", "Braintree-02"]},
      "70150" => {nil, ["71150"]},
      "70151" => {nil, ["71151"]},
      "70200" => {nil, ["71199"]},
      "70201" => {nil, ["Government Center-Brattle"]},
      "70202" => {nil, ["Government Center-Brattle"]}
    }
  }

  @doc """
  Transforms a list of stop IDs as per the given API version and options.

  * `only_renames: true` expands the list using only stop ID renames, ignoring additions.
  * `mappings: %{...}` supplies a custom set of mappings (see the moduledoc for details).
  """
  @spec expand([Stop.id()], String.t(), keyword) :: [Stop.id()]
  def expand(stop_ids, api_version, opts \\ []) do
    all_mappings = Keyword.get(opts, :mappings, @mappings)
    only_renames = Keyword.get(opts, :only_renames, false)

    mappings =
      all_mappings
      |> Stream.filter(fn {version, _mapping} -> api_version < version end)
      |> Enum.sort_by(fn {version, _mapping} -> version end)
      |> Enum.map(fn {_version, mapping} -> mapping end)

    Enum.reduce(mappings, stop_ids, fn mapping, ids ->
      Enum.reduce(ids, [], fn stop_id, acc ->
        {renamed_to, added} = Map.get(mapping, stop_id, {nil, []})

        # credo:disable-for-lines:4 Credo.Check.Refactor.Nesting
        new_ids =
          if only_renames,
            do: List.wrap(renamed_to),
            else: Enum.reject([renamed_to | added], &is_nil/1)

        acc ++ [stop_id | new_ids]
      end)
    end)
  end
end
