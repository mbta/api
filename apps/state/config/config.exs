# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :state, :shape,
  overrides: %{
    # Green Line
    # Green-B (Lechmere)
    "810_0004" => -1,
    # Green-B (Lechmere)
    "810_0005" => -1,
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
    # Green-D (Lechmere),
    "840_0005" => -1,
    # Green-D (Lechmere)
    "850_0006" => -1,
    # Green-D (Lechmere)
    "850_0007" => -1,

    # Order the Red Line Ashmont first, and change the northbound names to
    # the names of the branch.
    "931_0009" => 2,
    "931_0010" => {2, "Ashmont"},
    "933_0009" => 1,
    "933_0010" => {1, "Braintree"},
    "934_0001" => {-1, "JFK / UMass"},

    # Silver Line
    # SL1: last trip, goes right by South Station
    "7410023" => -1,
    # SL2
    "7420025" => 3,
    # SL2 listed as _ in shaperoutevariants, but not actually primary
    "7420016" => -1,

    # Providence
    "9890008" => {nil, "Wickford Junction"},
    "9890003" => {nil, "Stoughton"},

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
    "9810006" => {nil, "Rockport"},
    "9810001" => {nil, "Newburyport"},

    # Alternate Routes
    # Haverhill / Lowell wildcat trip
    "9820004" => -1,

    # Bus overrides
    # Route 9 inbound to Copley
    "090111" => 3,
    # Route 39
    "390068" => 3,
    # Route 66
    "660085" => 3
  },
  suffix_overrides: %{
    # shuttles are all -1 priority
    "-S" => -1
  }

import_config "#{Mix.env()}.exs"
