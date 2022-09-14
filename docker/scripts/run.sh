#!/usr/bin/env bash

. /usr/local/bin/functions.sh

echo "Bootstrapping..."
/usr/local/bin/bootstrap.sh

generatePeerConfigs

if [ ! -f /data/base.conf ] || [ ! -f /data/peers.conf ]; then
  echo "ERROR: Missing configuration files!"
  exit 1
fi

cat /data/base.conf /data/peers.conf > /etc/wireguard/wg0.conf

wg-quick up wg0

while [ true ]; do
  echo "Sleeping..."
  sleep 1h
done
