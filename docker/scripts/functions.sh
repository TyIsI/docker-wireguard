#!/usr/bin/env bash

IP=/sbin/ip
WG=/usr/bin/wg
WGQ=/usr/bin/wg-quick

DEFAULT_ROUTER_V4_FILE=/data/default-router-v4

addLocalRoutesV4() {
  DEFAULT_ROUTER=$(cat ${DEFAULT_ROUTER_V4_FILE})

  echo "${LOCAL_SUBNETS}" | tr ',' '\n' | while read LOCAL_SUBNET; do
    if valid_ipv4_subnet ${LOCAL_SUBNET}; then
      ip route add ${LOCAL_SUBNET} via ${DEFAULT_ROUTER}
    fi
  done
}

bootstrap() {
  if [ ! -f /data/privatekey ]; then
    generatePrivateKey
  fi

  if [ ! -f /data/publickey ]; then
    generatePublicKey
  fi

  generateBaseConfig
}

checkV6() {
  IPV6ADDRESSES=$(${IP} -f inet6 addr)

  if [ "${IPV6ADDRESSES}" != "" ]; then
    return true
  fi

  return false
}

generatePrivateKey() {
  echo -n "Generating private key..."

  ${WG} genkey > /data/privatekey

  echo "DONE!"
}

generatePublicKey() {
  echo -n "Generating public key..."

  ${WG} pubkey < /data/privatekey > /data/publickey

  echo "DONE!"
}

generateBaseConfig() {
  echo -n "Generating base configuration..."

  {
    echo "[Interface]"
    echo "PrivateKey = $(cat /data/privatekey)"
    echo "ListenPort = ${SERVER_PORT:-51820}"

    echo "${LOCAL_IPS}" | tr ',' '\n' | while read SERVER_IP; do
      if valid_ipv4_ip ${SERVER_IP}; then
        echo "Address = ${SERVER_IP}"
      fi
    done

    echo "PreUp = /usr/local/bin/control.sh pre-up"
    echo "PostUp = /usr/local/bin/control.sh post-up"

    echo "PreDown = /usr/local/bin/control.sh pre-down"
    echo "PostDown = /usr/local/bin/control.sh post-down"
  } > /data/base.conf

  echo "DONE!"
}

generatePeerConfigs() {
  PEERSET=$(set | perl -ne 'print $_ if /^PEER\_\d*\_/s' | cut -f2 -d'_' | sort -u | xargs)

  echo -n "Generating peer configurations for peers ${PEERSET}..."

  {
    for PEERSEQ in ${PEERSET}; do
      PEER_BASE="PEER_${PEERSEQ}"

      PEER_KEY=$(set | egrep "${PEER_BASE}_(PUBKEY|PUBLIC_KEY)" | cut -f2- -d'=')
      PEER_PSK=$(set | egrep "${PEER_BASE}_(PSK|PRE_SHARED_KEY)" | cut -f2- -d'=')
      PEER_ADDR=$(set | egrep "${PEER_BASE}_(ADDR|ADDRESS)" | cut -f2- -d'=')
      PEER_PORT=$(set | egrep "${PEER_BASE}_(PORT)" | cut -f2- -d'=')
      PEER_LOOKUP=$(set | egrep "${PEER_BASE}_(LOOKUP|RESOLVE)" | cut -f2- -d'=')
      PEER_KEEPALIVE=$(set | egrep "${PEER_BASE}_(KEEPALIVE)" | cut -f2- -d'=')
      PEER_SUBNETS=$(set | egrep "${PEER_BASE}_(SUBNETS)" | cut -f2- -d'=')

      echo ""
      echo "[Peer]"
      echo "PublicKey = ${PEER_KEY}"

      if [ "${PEER_PSK}" != "" ]; then
        echo "PresharedKey = ${PEER_PSK}"
      fi

      if [ "${PEER_PORT}" = "" ]; then
        PEER_PORT=${SERVER_PORT:-51820}
      fi

      if [ "${PEER_LOOKUP}" = "true" ] || [ "${PEER_LOOKUP}" != 0 ]; then
        REMOTE_ADDR=$(lookupPeerV4 ${PEER_ADDR})

        if [ "${REMOTE_ADDR}" != "" ]; then
          echo -n "Endpoint = ${REMOTE_ADDR}"
        else
          echo -n "Endpoint = ${PEER_ADDR}"
        fi
      else
        echo -n "Endpoint = ${PEER_ADDR}"
      fi

      echo ":${PEER_PORT}"

      echo -n "AllowedIPs = ${REMOTE_SUBNETS}"

      if [ "${PEER_SUBNETS}" != "" ]; then
        echo ",${PEER_SUBNETS}"
      else
        echo ""
      fi

      if [ "${PEER_KEEPALIVE}" != "" ]; then
        echo "PersistentKeepalive = ${PEER_KEEPALIVE}"
      fi

    done
  } > /data/peers.conf

  echo "DONE!"
}

lookupPeerV4() {
  echo "Looking up $1" > /dev/stderr
  dig $1 | egrep -v '^(;|$)' | egrep -w IN | egrep -w A | awk '{ print $5 }' | shuf -n 1
}

saveDefaultRouterV4() {
  ip route | egrep default | awk '{ print $3 }' > ${DEFAULT_ROUTER_V4_FILE}
}

valid_ipv4_ip() {
  local ip=$1
  local stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi

  return $stat
}

valid_ipv4_subnet() {
  local ip=$1
  local stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi

  return $stat
}

wgUp() {
  bootstrap
  ${WGQ} up wg0
}

wgDown() {
  ${WGQ} down wg0
}
