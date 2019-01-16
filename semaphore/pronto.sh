#!/bin/bash
set -ex

# This file used to run Pronto, which only checked for Credo failures on
# changes. Now, we check all files on each PR.
mix do deps.get, credo --strict
