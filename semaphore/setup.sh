#!/bin/bash
set -e

export MIX_HOME=$SEMAPHORE_CACHE_DIR/mix
mkdir -p $MIX_HOME

export ASDF_DATA_DIR=$SEMAPHORE_CACHE_DIR/.asdf

if [[ ! -d $ASDF_DATA_DIR ]]; then
  mkdir -p $ASDF_DATA_DIR
  git clone https://github.com/asdf-vm/asdf.git $ASDF_DATA_DIR --branch v0.7.8
fi

source $ASDF_DATA_DIR/asdf.sh
asdf update

asdf plugin-add erlang || true
asdf plugin-add elixir || true
asdf plugin-update --all
asdf install

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
