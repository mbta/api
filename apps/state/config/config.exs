# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
import Config

config :state, :shape,
  prefix_overrides: %{
    # Green Line
    # Green-B (Medford/Tufts)
    "8000014" => -1,
    # Green-B (Medford/Tufts)
    "8000019" => -1,
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
    # Green-C (Medford/Tufts)
    "8000016" => -1,
    # Green-C (Medford/Tufts)
    "8000017" => -1,
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
    # Green-D (Medford/Tufts)
    "8000020" => -1,
    # Green-D (Medford/Tufts)
    "8000021" => -1,
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
    # Green-E (Union Square)
    "8000001" => -1,
    # Green-E (Union Square)
    "8000002" => -1,
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
    # Green-E patterns that go to/from Union Square
    "Green-E-885-" => false,
    # Foxboro via Fairmount trips
    "CR-Franklin-Foxboro-" => true,
    # Rockport Branch shuttles
    "Shuttle-BeverlyRockportExpress-0-" => true,
    "Shuttle-BeverlyRockportLocal-0-" => true,
    "Shuttle-ManchesterGloucester-0-" => true,
    "Shuttle-ManchesterRockport-0-" => true,
    "Shuttle-OrientHeightsRockportExpress-0-" => true,
    "Shuttle-OrientHeightsRockportLimited-0-" => true,
    "Shuttle-OrientHeightsRockportLocal-0-" => true,
    "Shuttle-RockportWestGloucester-0-" => true,
    "Shuttle-RockportSalemExpress-0-" => true,
    "Shuttle-RockportSalemLocal-0-" => true,
    # Newburyport/Rockport Line trunk shuttles
    "Shuttle-BeverlyNorthStationExpress-0-" => true,
    "Shuttle-BeverlyNorthStationLocal-0-" => true,
    "Shuttle-BeverlyOrientHeightsExpress-0-" => true,
    "Shuttle-BeverlyOrientHeightsLocal-0-" => true,
    "Shuttle-BeverlyWellingtonExpress-0-" => true,
    "Shuttle-BeverlyWellingtonLocal-0-" => true,
    "Shuttle-ChelseaLynn-0-" => true,
    "Shuttle-LynnNorthStationExpress-0-" => true,
    "Shuttle-LynnSwampscott-0-" => true,
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
    "Shuttle-AndoverHaverhill-0-" => true,
    "Shuttle-HaverhillReadingExpress-0-" => true,
    "Shuttle-HaverhillReadingLocal-0-" => true,
    # Lowell Line shuttles
    "Shuttle-AndersonWoburnNorthStationExpress-0-" => true,
    "Shuttle-AndersonWoburnNorthStationLocal-0-" => true,
    # Old Colony Lines shuttles/suspension
    "Shuttle-BraintreeSouthStationExpress-0-" => true,
    "CR-Greenbush-BraintreeGreenbush-" => true
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
        "place-orhte",
        "place-welln",
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
        "place-welln",
        "place-orhte",
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
    ],
    {"CR-Greenbush", 0} => [
      [
        "place-jfk",
        "place-qnctr",
        "place-brntn",
        "place-GRB-0118"
      ]
    ],
    {"CR-Greenbush", 1} => [
      [
        "place-GRB-0118",
        "place-brntn",
        "place-qnctr",
        "place-jfk"
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
    {"Green-B", 0} => [
      "9070150",
      "951",
      "952",
      "953",
      "956",
      "958",
      "9070131",
      "9070129",
      "9070121",
      "9070117",
      "9070115",
      "9070113",
      "9070111",
      "9070107"
    ],
    {"Green-B", 1} => [
      "9070107",
      "9070110",
      "9070112",
      "9070114",
      "9070116",
      "9170120",
      "9070128",
      "9070130",
      "933",
      "934",
      "938",
      "939",
      "941",
      "9070150"
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
      "place-mdftf",
      "place-balsq",
      "place-mgngl",
      "place-gilmn",
      "place-esomr",
      "9070150",
      "9434",
      "1521",
      "11366",
      "9070178",
      "1540",
      "9070171",
      "9170169",
      "8206",
      "9070165",
      "9070162"
    ],
    {"Green-D", 1} => [
      "9070162",
      "9070164",
      "8153",
      "9170168",
      "9070170",
      "1984",
      "9070179",
      "9070180",
      "1804",
      "1807",
      "9070150",
      "place-esomr",
      "place-gilmn",
      "place-mgngl",
      "place-balsq",
      "place-mdftf"
    ],
    {"Green-E", 0} => [
      "place-unsqu",
      "14159",
      "21458",
      "9070206",
      "30203",
      "9070026",
      "4510",
      "9070503",
      "9070501",
      "9070093",
      "9170206",
      "9070024"
    ],
    {"Green-E", 1} => [
      "14155",
      "21458",
      "4510",
      "9070026",
      "4511",
      "9070090",
      "9070091",
      "9070501",
      "9070503",
      "place-unsqu"
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
    ],
    {"Orange", 0} => [
      "9070039",
      "6565"
    ],
    {"Orange", 1} => [
      "6565",
      "6537",
      "9070039"
    ],
    {"Red", 0} => [
      "110",
      "72",
      "9070069",
      "9170071",
      "9070072",
      "9070073",
      "9170076",
      "2231",
      "2581",
      "12301"
    ],
    {"Red", 1} => [
      "9170076",
      "9070074",
      "9070070",
      "23151",
      "2231",
      "102",
      "110"
    ]
  }

import_config "#{config_env()}.exs"
