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
    },
    "2020-XX-XX" => %{
      "Abington" => {"PB-0194-S", []},
      "Anderson/ Woburn" => {"NHRML-0127", ["NHRML-0127-01", "NHRML-0127-02"]},
      "Andover" => {"WR-0228-02", []},
      "Ashland" => {"WML-0252", ["WML-0252-01", "WML-0252-02"]},
      "Attleboro" => {"NEC-1969", ["NEC-1969-03", "NEC-1969-04"]},
      "Auburndale" => {"WML-0102-02", []},
      "Ayer" => {"FR-0361", ["FR-0361-01", "FR-0361-02"]},
      "Back Bay" => {"NEC-2276", []},
      "Back Bay-01" => {"NEC-2276-01", []},
      "Back Bay-02" => {"NEC-2276-02", []},
      "Back Bay-03" => {"NEC-2276-03", []},
      "Back Bay-05" => {"WML-0012-05", []},
      "Back Bay-07" => {"WML-0012-07", []},
      "Ballardvale" => {"WR-0205-02", []},
      "Bellevue" => {"NB-0072-S", []},
      "Belmont" => {"FR-0064", ["FR-0064-01", "FR-0064-02"]},
      "Beverly Farms" => {"GB-0229", ["GB-0229-01", "GB-0229-02"]},
      "Beverly" => {"ER-0183", ["ER-0183-01", "ER-0183-02"]},
      "Blue Hill Avenue" => {"DB-2222", ["DB-2222-01", "DB-2222-02"]},
      "Boston Landing" => {"WML-0035", ["WML-0035-01", "WML-0035-02"]},
      "Bourne" => {"CM-0564-S", []},
      "Bradford" => {"WR-0325", ["WR-0325-01", "WR-0325-02"]},
      "Braintree" => {"MM-0109", ["MM-0109-CS", "MM-0109-S"]},
      "Brandeis/ Roberts" => {"FR-0115", ["FR-0115-01", "FR-0115-02"]},
      "Bridgewater" => {"MM-0277-S", []},
      "Brockton" => {"MM-0200", ["MM-0200-CS", "MM-0200-S"]},
      "Buzzards Bay" => {"CM-0547-S", []},
      "Campello" => {"MM-0219-S", []},
      "Canton Center" => {"SB-0156-S", []},
      "Canton Junction" =>
        {"NEC-2139", ["NEC-2139-01", "NEC-2139-02", "SB-0150-04", "SB-0150-06"]},
      "Chelsea" => {"ER-0046", ["ER-0046-01", "ER-0046-02"]},
      "Cohasset" => {"GRB-0199-S", []},
      "Concord" => {"FR-0201", ["FR-0201-01", "FR-0201-02"]},
      "Dedham Corp Center" => {"FB-0118", ["FB-0118-01", "FB-0118-02"]},
      "East Weymouth" => {"GRB-0146-S", []},
      "Endicott" => {"FB-0109", ["FB-0109-01", "FB-0109-02"]},
      "Fairmount" => {"DB-2205", ["DB-2205-01", "DB-2205-02"]},
      "Fitchburg" => {"FR-0494-CS", []},
      "Forest Hills" => {"NEC-2237", ["NEC-2237-03", "NEC-2237-05"]},
      "Forge Park / 495" => {"FB-0303-S", []},
      "Four Corners / Geneva" => {"DB-2249", ["DB-2249-01", "DB-2249-02"]},
      "Foxboro" => {"FS-0049-S", []},
      "Framingham" => {"WML-0214", ["WML-0214-01", "WML-0214-02"]},
      "Franklin" => {"FB-0275-S", []},
      "Gloucester" => {"GB-0316-S", []},
      "Grafton" => {"WML-0364", ["WML-0364-01", "WML-0364-02"]},
      "Greenbush" => {"GRB-0276-S", []},
      "Greenwood" => {"WR-0085", ["WR-0085-01", "WR-0085-02"]},
      "Halifax" => {"PB-0281", ["PB-0281-CS", "PB-0281-S"]},
      "Hamilton/ Wenham" => {"ER-0227-S", []},
      "Hanson" => {"PB-0245-S", []},
      "Hastings" => {"FR-0137", ["FR-0137-01", "FR-0137-02"]},
      "Haverhill" => {"WR-0329", ["WR-0329-01", "WR-0329-02"]},
      "Hersey" => {"NB-0109-S", []},
      "Highland" => {"NB-0076-S", []},
      "Holbrook/ Randolph" => {"MM-0150-S", []},
      "Hyannis" => {"CM-0790-S", []},
      "Hyde Park" => {"NEC-2203", ["NEC-2203-02", "NEC-2203-03"]},
      "Ipswich" => {"ER-0276-S", []},
      "Islington" => {"FB-0125", ["FB-0125-01", "FB-0125-02"]},
      "JFK/UMASS" => {"MM-0023-S", []},
      "Kendal Green" => {"FR-0132", ["FR-0132-01", "FR-0132-02"]},
      "Kingston" => {"KB-0351-S", []},
      "Lawrence" => {"WR-0264-02", []},
      "Lincoln" => {"FR-0167", ["FR-0167-01", "FR-0167-02"]},
      "Littleton / Rte 495" => {"FR-0301", ["FR-0301-01", "FR-0301-02"]},
      "Lowell" => {"NHRML-0254", ["NHRML-0254-03", "NHRML-0254-04"]},
      "Lynn" => {"ER-0115", ["ER-0115-01", "ER-0115-02"]},
      "Malden Center" => {"WR-0045-S", []},
      "Manchester" => {"GB-0254", ["GB-0254-01", "GB-0254-02"]},
      "Mansfield" => {"NEC-2040", ["NEC-2040-01", "NEC-2040-02"]},
      "Melrose Cedar Park" => {"WR-0067", ["WR-0067-01", "WR-0067-02"]},
      "Melrose Highlands" => {"WR-0075", ["WR-0075-01", "WR-0075-02"]},
      "Middleborough/ Lakeville" => {"MM-0356-S", []},
      "Mishawum" => {"NHRML-0116", ["NHRML-0116-01", "NHRML-0116-02"]},
      "Montello" => {"MM-0186", ["MM-0186-CS", "MM-0186-S"]},
      "Montserrat" => {"GB-0198", ["GB-0198-01", "GB-0198-02"]},
      "Morton Street" => {"DB-2230", ["DB-2230-01", "DB-2230-02"]},
      "Nantasket Junction" => {"GRB-0183-S", []},
      "Natick Center" => {"WML-0177", ["WML-0177-01", "WML-0177-02"]},
      "Needham Center" => {"NB-0127-S", []},
      "Needham Heights" => {"NB-0137-S", []},
      "Needham Junction" => {"NB-0120-S", []},
      "Newburyport" => {"ER-0362", ["ER-0362-01", "ER-0362-02"]},
      "Newmarket" => {"DB-2265", ["DB-2265-01", "DB-2265-02"]},
      "Newtonville" => {"WML-0081-02", []},
      "Norfolk" => {"FB-0230-S", []},
      "North Beverly" => {"ER-0208", ["ER-0208-01", "ER-0208-02"]},
      "North Billerica" => {"NHRML-0218", ["NHRML-0218-01", "NHRML-0218-02"]},
      "North Leominster" => {"FR-0451", ["FR-0451-01", "FR-0451-02"]},
      "North Scituate" => {"GRB-0233-S", []},
      "North Station" => {"BNT-0000", []},
      "North Station-01" => {"BNT-0000-01", []},
      "North Station-02" => {"BNT-0000-02", []},
      "North Station-03" => {"BNT-0000-03", []},
      "North Station-04" => {"BNT-0000-04", []},
      "North Station-05" => {"BNT-0000-05", []},
      "North Station-06" => {"BNT-0000-06", []},
      "North Station-07" => {"BNT-0000-07", []},
      "North Station-08" => {"BNT-0000-08", []},
      "North Station-09" => {"BNT-0000-09", []},
      "North Station-10" => {"BNT-0000-10", []},
      "North Wilmington" => {"WR-0163-S", []},
      "Norwood Central" => {"FB-0148", ["FB-0148-01", "FB-0148-02"]},
      "Norwood Depot" => {"FB-0143", ["FB-0143-01", "FB-0143-02"]},
      "place-dudly" => {"place-nubn", []},
      "Plimptonville" => {"FB-0177-S", []},
      "Plymouth" => {"PB-0356-S", []},
      "Porter Square" => {"FR-0034", ["FR-0034-01", "FR-0034-02"]},
      "Prides Crossing" => {"GB-0222", ["GB-0222-01", "GB-0222-02"]},
      "Providence" => {"NEC-1851", ["NEC-1851-01", "NEC-1851-02", "NEC-1851-03", "NEC-1851-05"]},
      "Quincy Center" => {"MM-0079-S", []},
      "Reading" => {"WR-0120-S", []},
      "Readville" => {"DB-0095", ["FB-0095-04", "FB-0095-05", "NEC-2192-02", "NEC-2192-03"]},
      "River Works / GE Employees Only" => {"ER-0099", ["ER-0099-01", "ER-0099-02"]},
      "Rockport" => {"GB-0353-S", []},
      "Roslindale Village" => {"NB-0064-S", []},
      "Route 128" => {"NEC-2173", ["NEC-2173-01", "NEC-2173-02"]},
      "Rowley" => {"ER-0312-S", []},
      "Ruggles" => {"NEC-2265", []},
      "Ruggles-01" => {"NEC-2265-01", []},
      "Ruggles-02" => {"NEC-2265-02", []},
      "Ruggles-03" => {"NEC-2265-03", []},
      "Salem" => {"ER-0168-S", []},
      "Sharon" => {"NEC-2108", ["NEC-2108-01", "NEC-2108-02"]},
      "Shirley" => {"FR-0394", ["FR-0394-01", "FR-0394-02"]},
      "Silver Hill" => {"FR-0147", ["FR-0147-01", "FR-0147-02"]},
      "South Acton" => {"FR-0253", ["FR-0253-01", "FR-0253-02"]},
      "South Attleboro" => {"NEC-1919", ["NEC-1919-01", "NEC-1919-02"]},
      "South Station" => {"NEC-2287", []},
      "South Station-01" => {"NEC-2287-01", []},
      "South Station-02" => {"NEC-2287-02", []},
      "South Station-03" => {"NEC-2287-03", []},
      "South Station-04" => {"NEC-2287-04", []},
      "South Station-05" => {"NEC-2287-05", []},
      "South Station-06" => {"NEC-2287-06", []},
      "South Station-07" => {"NEC-2287-07", []},
      "South Station-08" => {"NEC-2287-08", []},
      "South Station-09" => {"NEC-2287-09", []},
      "South Station-10" => {"NEC-2287-10", []},
      "South Station-11" => {"NEC-2287-11", []},
      "South Station-12" => {"NEC-2287-12", []},
      "South Station-13" => {"NEC-2287-13", []},
      "South Weymouth" => {"PB-0158-S", []},
      "Southborough" => {"WML-0274", ["WML-0274-01", "WML-0274-02"]},
      "Stoughton" => {"SB-0189-S", []},
      "Swampscott" => {"ER-0128", ["ER-0128-01", "ER-0128-02"]},
      "Talbot Avenue" => {"DB-2240", ["DB-2240-01", "DB-2240-02"]},
      "TF Green Airport" => {"NEC-1768-03", []},
      "Uphams Corner" => {"DB-2258", ["DB-2258-01", "DB-2258-02"]},
      "Wachusett" => {"FR-3338-CS", []},
      "Wakefield" => {"WR-0099", ["WR-0099-01", "WR-0099-02"]},
      "Walpole" => {"FB-0191-S", []},
      "Waltham" => {"FR-0098", ["FR-0098-01", "FR-0098-S"]},
      "Wareham Village" => {"CM-0493-S", []},
      "Waverley" => {"FR-0074", ["FR-0074-01", "FR-0074-02"]},
      "Wedgemere" => {"NHRML-0073", ["NHRML-0073-01", "NHRML-0073-02"]},
      "Wellesley Farms" => {"WML-0125", ["WML-0125-01", "WML-0125-02"]},
      "Wellesley Hills" => {"WML-0135", ["WML-0135-01", "WML-0135-02"]},
      "Wellesley Square" => {"WML-0147", ["WML-0147-01", "WML-0147-02"]},
      "West Concord" => {"FR-0219", ["FR-0219-01", "FR-0219-02"]},
      "West Gloucester" => {"GB-0296", ["GB-0296-01", "GB-0296-02"]},
      "West Hingham" => {"GRB-0162-S", []},
      "West Medford" => {"NHRML-0055", ["NHRML-0055-01", "NHRML-0055-02"]},
      "West Natick" => {"WML-0199", ["WML-0199-01", "WML-0199-02"]},
      "West Newton" => {"WML-0091-02", []},
      "West Roxbury" => {"NB-0080-S", []},
      "Westborough" => {"WML-0340", ["WML-0340-01", "WML-0340-02"]},
      "Weymouth Landing/ East Braintree" => {"GRB-0118-S", []},
      "Whitman" => {"PB-0212-S", []},
      "Wickford Junction" => {"NEC-1659-03", []},
      "Wilmington" => {"NHRML-0152", ["NHRML-0152-01", "NHRML-0152-02"]},
      "Winchester Center" => {"NHRML-0078", ["NHRML-0078-01", "NHRML-0078-02"]},
      "Windsor Gardens" => {"FB-0166-S", []},
      "Worcester" => {"WML-0442-CS", []},
      "Wyoming Hill" => {"WR-0062", ["WR-0062-01", "WR-0062-02"]},
      "Yawkey" => {"WML-0025", ["WML-0025-05", "WML-0025-07"]}
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
