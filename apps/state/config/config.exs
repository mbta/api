# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :state, :route_pattern,
  ignore_override_prefixes: %{
    # don't ignore Foxboro via Fairmount trips
    "CR-Franklin-3-0" => false,
    "CR-Franklin-3-1" => false,
    "CR-Franklin-Foxboro-" => false,
    # ignore North Station Green-D patterns
    "Green-D-1-1" => true,
    "Green-D-3-1" => true,
    # don't ignore Rockport Branch shuttles
    "Shuttle-ManchesterGloucester-0-0" => false,
    "Shuttle-ManchesterGloucester-0-1" => false,
    "Shuttle-ManchesterRockport-0-0" => false,
    "Shuttle-ManchesterRockport-0-1" => false,
    "Shuttle-RockportWestGloucester-0-0" => false,
    "Shuttle-RockportWestGloucester-0-1" => false
  }

config :state, :shape,
  prefix_overrides: %{
    # Green Line
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

    # Kingston
    # Kingston (from Kingston) inbound
    "9790001" => -1,
    # Kingston inbound
    "9790003" => -1,
    # Kingston (from Plymouth) inbound
    "9790005" => -1,
    # Kingston inbound: from Plymouth through Kingston
    "9790007" => 2,
    # Kingston outbound (to Kingston)
    "9790002" => -1,
    # Kingston outbound (to Kingston then Plymouth)
    "9790004" => 2,
    # Kingston outbound (to Plymouth but without JFK)
    "9790006" => -1,
    # Kingston outbound
    "9790008" => -1,

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
    {"CR-Newburyport", 0} => [
      [
        "Montserrat",
        "Prides Crossing",
        "Beverly Farms",
        "Manchester",
        "West Gloucester",
        "Gloucester",
        "Rockport"
      ],
      [
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
        "Rockport",
        "Gloucester",
        "West Gloucester",
        "Manchester",
        "Beverly Farms",
        "Prides Crossing",
        "Montserrat"
      ],
      [
        "place-GB-0353",
        "place-GB-0316",
        "place-GB-0296",
        "place-GB-0254",
        "place-GB-0229",
        "place-GB-0222",
        "place-GB-0198"
      ]
    ]
  },
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
    {"Green-D", 0} => [
      "place-lech",
      "place-spmnl",
      "place-north",
      "place-haecl"
    ],
    {"Green-D", 1} => [
      "place-lech",
      "place-spmnl",
      "place-north",
      "place-haecl"
    ],
    {"Green-E", 0} => [
      "place-lech",
      "14159",
      "21458"
    ],
    {"Green-E", 1} => [
      "place-lech",
      "14155",
      "21458"
    ]
  }

import_config "#{Mix.env()}.exs"
