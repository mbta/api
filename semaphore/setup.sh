#!/bin/bash
set -e
ELIXIR_VERSION=1.10.2
ERLANG_VERSION=22.3

export MIX_HOME=$SEMAPHORE_CACHE_DIR/mix
mkdir -p $MIX_HOME

export ERL_HOME="${SEMAPHORE_CACHE_DIR}/.kerl/installs/${ERLANG_VERSION}"

env

if [ "x$SEMAPHORE_PLATFORM" = "xbionic-kvm" ]; then
    sem-version erlang $ERLANG_VERSION
else
    if [ ! -d "${ERL_HOME}" ]; then
        mkdir -p "${ERL_HOME}"
        KERL_BUILD_BACKEND=git kerl build $ERLANG_VERSION $ERLANG_VERSION
        kerl install $ERLANG_VERSION $ERL_HOME
    fi

    . $ERL_HOME/activate
fi

if [ "x$SEMAPHORE_PLATFORM" = "xbionic-kvm" ]; then
    sem-version elixir $ELIXIR_VERSION
else
    if ! kiex use $ELIXIR_VERSION; then
        kiex install $ELIXIR_VERSION
        kiex use $ELIXIR_VERSION
    fi
fi

mix local.hex --force
mix local.rebar --force

if [ "x$SEMAPHORE_PLATFORM" != "xbionic-kvm" ]; then
    # Turn off some high-memory apps
    SERVICES="cassandra elasticsearch mysql mongod docker postgresql apache2 redis-server rabbitmq-server"
    for service in $SERVICES; do
        sudo service $service stop
    done
    killall Xvfb
fi

# Add more swap memory. Default is ~200m, make it 5G
sudo swapoff -a
sudo dd if=/dev/zero of=/swapfile bs=1M count=5120
sudo mkswap /swapfile
sudo swapon /swapfile
