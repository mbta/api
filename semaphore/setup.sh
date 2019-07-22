#!/bin/bash
set -e
ELIXIR_VERSION=1.9.1
ERLANG_VERSION=22.0.7

export MIX_HOME=$SEMAPHORE_CACHE_DIR/mix
mkdir -p $MIX_HOME

export LOCK_FILE="${SEMAPHORE_CACHE_DIR}/kerl.lock"
export LOCK_HANDLE=200
export ERL_HOME="${SEMAPHORE_CACHE_DIR}/.kerl/installs/${ERLANG_VERSION}"

# make sure we don't build erlang in parallel 
{
    flock -x $LOCK_HANDLE
    if [ ! -d "${ERL_HOME}" ]; then
        KERL_BUILD_BACKEND=git kerl build $ERLANG_VERSION $ERLANG_VERSION
        kerl install $ERLANG_VERSION $ERL_HOME
    fi

    . $ERL_HOME/activate

} $LOCK_HANDLE>$LOCK_FILE

if ! kiex use $ELIXIR_VERSION; then
    kiex install $ELIXIR_VERSION
    kiex use $ELIXIR_VERSION
fi
mix local.hex --force
mix local.rebar --force

# Turn off some high-memory apps
SERVICES="cassandra elasticsearch mysql mongod docker postgresql apache2 redis-server"
if ! grep 1706 /etc/hostname > /dev/null; then
    # Platform version 1706 has a bug with stopping RabbitMQ.  If we're not
    # on that version, we can stop that service.
    SERVICES="rabbitmq-server $SERVICES"
fi
for service in $SERVICES; do
    sudo service $service stop
done
killall Xvfb

# Add more swap memory. Default is ~200m, make it 5G
sudo swapoff -a
sudo dd if=/dev/zero of=/swapfile bs=1M count=5120
sudo mkswap /swapfile
sudo swapon /swapfile
