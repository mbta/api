#!/bin/bash
set -e
ELIXIR_VERSION=1.8.1
ERLANG_VERSION=21

export MIX_HOME=$SEMAPHORE_CACHE_DIR/mix
mkdir -p $MIX_HOME

. /home/runner/.kerl/installs/$ERLANG_VERSION/activate
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
