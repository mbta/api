#!/bin/bash
set -ex

# make sure the dev-environment is setup
$(dirname $0)/deps_get.sh
mix compile

# copy any pre-built PLTs to the right directory
find $SEMAPHORE_CACHE_DIR -name "dialyxir_*elixir-${ELIXIR_VERSION}_deps-dev.plt*" | xargs -I{} cp '{}' _build/dev

export ERL_CRASH_DUMP=/dev/null
mix dialyzer --plt

# copy build PLTs back
cp _build/dev/*_deps-dev.plt* $SEMAPHORE_CACHE_DIR

mix dialyzer --halt-exit-status
