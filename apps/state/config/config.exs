# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :state, :shape,
  prefix_overrides: %{
    # Green Line
    # Green-D (Union Square)
    "8000008" => -1,
    # Green-D (Union Square)
    "8000009" => -1,
    # Green-B (Lechmere)
    "810_0004" => -1,
    # Green-B (Lechmere)
    "810_0005" => -1,
    # Green-B (Lechmere)
    "810_0006" => -1,
    # Green-B (Lechmere)
    "810_0007" => -1,
    # Green-B (Lechmere)
    "810_0008" => -1,
    # Green-B (North Station)
    "811_0007" => -1,
    # Green-B (North Station)
    "811_0008" => -1,
    # Green-B (North Station)
    "811_0009" => -1,
    # Green-B (North Station)
    "811_0010" => -1,
    # Green-B (North Station)
    "811_0011" => -1,
    # Green-B (North Station)
    "811_0012" => -1,
    # Green-B (North Station)
    "811_0013" => -1,
    # Green-B (North Station)
    "811_0014" => -1,
    # Green-B (North Station)
    "811_0015" => -1,
    # Green-B (North Station)
    "811_0016" => -1,
    # Green-B
    "813_0003" => 2,
    # Green-B
    "813_0004" => 2,
    # Green-B (Blandford)
    "803_0001" => -1,
    # Green-B (Blandford)
    "803_0002" => -1,
    # Green-B (Blandford)
    "803t0001" => -1,
    # Green-B (Blandford)
    "803t0003" => -1,
    # Green-C (Lechmere)
    "830_0003" => -1,
    # Green-C (Lechmere)
    "830_0004" => -1,
    # Green-C (Lechmere)
    "830_0005" => -1,
    # Green-C (Lechmere)
    "830_0006" => -1,
    # Green-C (Park)
    "833t0001" => -1,
    # Green-C (Park)
    "833t0002" => -1,
    # Green-C (Park)
    "833_0001" => -1,
    # Green-C (Park)
    "833_0002" => -1,
    # Green-C
    "831_0008" => 2,
    # Green-C
    "831_0009" => 2,
    # Green-D (Lechmere)
    "840_0004" => -1,
    # Green-D (Lechmere)
    "840_0005" => -1,
    # Green-D (Lechmere)
    "840_0008" => -1,
    # Green-D (Lechmere)
    "840_0009" => -1,
    # Green-D (North Station)
    "841_0005" => -1,
    # Green-D (North Station)
    "841_0006" => -1,
    # Green-D (North Station)
    "841_0007" => -1,
    # Green-D (Lechmere)
    "850_0006" => -1,
    # Green-D (Lechmere)
    "850_0007" => -1,
    # Green-D (Lechmere)
    "850_0010" => -1,
    # Green-D (Lechmere)
    "850_0011" => -1,
    # Green-D (North Station)
    "851_0008" => -1,
    # Green-D (North Station)
    "851_0009" => -1,
    # Green-D (North Station)
    "851_0010" => -1,
    # Green-D (North Station)
    "851_0012" => -1,
    # Green-D (Newton Highlands)
    "858_0002" => -1,
    # Green-D (Newton Highlands)
    "858t0001" => -1,
    # Green-D (Newton Highlands)
    "858t0002" => -1,
    # Green-E (Prudential)
    "881_0012" => -1,
    # Green-E (Prudential)
    "881_0013" => -1,
    # Green-E (shuttle bus)
    "6020021" => -1,
    "6020022" => -1,

    # Order the Red Line Ashmont first, and change the northbound names to
    # the names of the branch.
    "931_0009" => 2,
    "931_0010" => 2,
    "933_0009" => 1,
    "933_0010" => 1,

    # Silver Line
    # SL1: last trip, goes right by South Station
    "7410023" => -1,
    # SL2
    "7420025" => 3,
    # SL2 listed as _ in shaperoutevariants, but not actually primary
    "7420016" => -1,

    # Providence
    "9890008" => {nil, "Wickford Junction - South Station"},
    "9890009" => {nil, "South Station - Wickford Junction"},
    "9890003" => {nil, "Stoughton - South Station"},

    # Newburyport
    "9810006" => {nil, "Rockport - North Station"},
    "9810001" => {nil, "Newburyport - North Station"},

    # Alternate Routes
    # Haverhill / Lowell wildcat trip
    "9820004" => -1,

    # Bus overrides
    # Route 9 inbound to Copley
    "090145" => 3,
    # Route 39
    "390068" => 3,
    # Route 66
    "660085" => 3
  },
  suffix_overrides: %{
    # shuttles are all -1 priority
    "-S" => -1
  }

# Overrides whether specific trips (by route pattern prefix) should be used in determining the
# "canonical" set of stops for a route
config :state, :stops_on_route,
  route_pattern_prefix_overrides: %{
    # Green-D patterns that go to North Station
    "Green-D-851-1" => false,
    "Green-D-841-1" => false,
    # Foxboro via Fairmount trips
    "CR-Franklin-Foxboro-" => true,
    # Rockport Branch shuttles
    "Shuttle-BeverlyRockport-0-" => true,
    "Shuttle-ManchesterGloucester-0-" => true,
    "Shuttle-ManchesterRockport-0-" => true,
    "Shuttle-RockportWestGloucester-0-" => true,
    "Shuttle-RockportSalemExpress-0-" => true,
    "Shuttle-RockportSalemLocal-0-" => true,
    # Newburyport/Rockport Line trunk shuttles
    "Shuttle-ChelseaLynn-0-" => true,
    "Shuttle-LynnNorthStationExpress-0-" => true,
    "CR-Newburyport-adde8a7c-" => true,
    "CR-Newburyport-76fa2c91-" => true,
    "CR-Newburyport-173cb7ae-" => true,
    "CR-Newburyport-ff47d622-" => true,
    # Newburyport Branch shuttles
    "Shuttle-BeverlyNewburyportExpress-0-" => true,
    "Shuttle-BeverlyNewburyportLocal-0-" => true,
    "Shuttle-NewburyportSalemExpress-0-" => true,
    "Shuttle-NewburyportSalemLocal-0-" => true,
    # Fitchburg Line shuttles to/from Alewife
    "Shuttle-AlewifeLittletonExpress-0-" => true,
    "Shuttle-AlewifeLittletonLocal-0-" => true,
    # Fitchburg Line shuttles to/from Wachusett
    "Shuttle-LittletonWachusett-0-" => true,
    # Newton Connection RailBus for Worcester Line
    "Shuttle-NewtonHighlandsWellesleyFarms-0-" => true,
    # Kingston Line shuttles to/from South Weymouth
    "Shuttle-BraintreeSouthWeymouth-0-" => true,
    # Providence trains stopping at Forest Hills
    "CR-Providence-d01bc229-0" => true,
    # Haverhill Line shuttles to/from Malden Center
    "Shuttle-BallardvaleMaldenCenter-0-" => true,
    "Shuttle-HaverhillMaldenCenter-0-" => true,
    "Shuttle-AndoverHaverhill-0-" => true
  }

# Overrides for the stop ordering on routes where the trips themselves aren't enough
config :state, :stops_on_route,
  stop_order_overrides: %{
    {"CR-Franklin", 0} => [
      ["Norwood Central", "Windsor Gardens", "Plimptonville", "Walpole"],
      ["place-FB-0148", "place-FB-0166", "place-FB-0177", "place-FB-0191"],
      ["Walpole", "Foxboro", "Norfolk"],
      ["place-FB-0191", "place-FS-0049", "place-FB-0230"]
    ],
    {"CR-Franklin", 1} => [
      ["Norfolk", "Foxboro", "Walpole"],
      ["place-FB-0230", "place-FS-0049", "place-FB-0191"]
    ],
    {"CR-Fairmount", 0} => [
      ["Readville", "Dedham Corp Center", "Foxboro"],
      ["place-DB-0095", "place-FB-0118", "place-FS-0049"]
    ],
    {"CR-Fairmount", 1} => [
      ["Foxboro", "Dedham Corp Center", "Readville"],
      ["place-FS-0049", "place-FB-0118", "place-DB-0095"]
    ],
    {"CR-Fitchburg", 0} => [
      ["place-portr", "place-alfcl", "place-FR-0064"],
      ["place-FR-0253", "place-FR-0301", "place-FR-0361"]
    ],
    {"CR-Fitchburg", 1} => [
      ["place-FR-0361", "place-FR-0301", "place-FR-0253"],
      ["place-FR-0064", "place-alfcl", "place-portr"]
    ],
    {"CR-Newburyport", 0} => [
      [
        "place-north",
        "place-ogmnl",
        "place-chels",
        "place-ER-0099",
        "place-ER-0115",
        "place-ER-0128",
        "place-ER-0168",
        "place-ER-0183",
        "place-ER-0208",
        "place-ER-0227",
        "place-ER-0276",
        "place-ER-0312",
        "place-ER-0362",
        "place-GB-0198",
        "place-GB-0222",
        "place-GB-0229",
        "place-GB-0254",
        "place-GB-0296",
        "place-GB-0316",
        "place-GB-0353"
      ]
    ],
    {"CR-Newburyport", 1} => [
      [
        "place-GB-0353",
        "place-GB-0316",
        "place-GB-0296",
        "place-GB-0254",
        "place-GB-0229",
        "place-GB-0222",
        "place-GB-0198",
        "place-ER-0362",
        "place-ER-0312",
        "place-ER-0276",
        "place-ER-0227",
        "place-ER-0208",
        "place-ER-0183",
        "place-ER-0168",
        "place-ER-0128",
        "place-ER-0115",
        "place-ER-0099",
        "place-chels",
        "place-ogmnl",
        "place-north"
      ]
    ],
    {"CR-Worcester", 0} => [
      [
        "place-WML-0035",
        "place-newtn",
        "place-WML-0081",
        "place-WML-0091",
        "place-WML-0102",
        "place-river",
        "place-WML-0125"
      ]
    ],
    {"CR-Worcester", 1} => [
      [
        "place-WML-0125",
        "place-river",
        "place-WML-0102",
        "place-WML-0091",
        "place-WML-0081",
        "place-newtn",
        "place-WML-0035"
      ]
    ],
    {"CR-Providence", 0} => [
      [
        "place-rugg",
        "place-forhl",
        "place-NEC-2203"
      ]
    ]
  }

# Stops that should never be considered to be "on" a given route
config :state, :stops_on_route,
  not_on_route: %{
    {"CR-Franklin", 0} => [
      "place-DB-2265",
      "place-DB-2258",
      "place-DB-2249",
      "place-DB-2240",
      "place-DB-2230",
      "place-DB-2222",
      "place-DB-2205"
    ],
    {"CR-Franklin", 1} => [
      "place-DB-2265",
      "place-DB-2258",
      "place-DB-2249",
      "place-DB-2240",
      "place-DB-2230",
      "place-DB-2222",
      "place-DB-2205"
    ],
    {"CR-Fairmount", 0} => [
      "place-FB-0166",
      "place-FB-0148",
      "place-FB-0143",
      "place-FB-0125",
      "place-FB-0109"
    ],
    {"CR-Fairmount", 1} => [
      "place-FB-0166",
      "place-FB-0148",
      "place-FB-0143",
      "place-FB-0125",
      "place-FB-0109"
    ],
    {"Green-C", 0} => [
      "place-north",
      "place-haecl"
    ],
    {"Green-C", 1} => [
      "place-north",
      "place-haecl"
    ],
    {"Green-D", 0} => [
      "palce-unsqu",
      "place-lech",
      "place-spmnl"
    ],
    {"Green-D", 1} => [
      "place-unsqu",
      "place-lech",
      "place-spmnl"
    ],
    {"Green-E", 0} => [
      "14159",
      "21458",
      "9070206",
      "30203",
      "4510"
    ],
    {"Green-E", 1} => [
      "14155",
      "21458",
      "4510",
      "4511"
    ],
    {"CR-Needham", 0} => [
      "place-NEC-2203",
      "place-NEC-2173",
      "place-NEC-2139",
      "place-NEC-2108",
      "place-NEC-2040",
      "place-NEC-1969",
      "place-NEC-1919",
      "place-NEC-1851",
      "place-NEC-1768",
      "place-NEC-1659"
    ]
  }

import_config "#{config_env()}.exs"
