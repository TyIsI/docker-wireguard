#!/bin/bash

cd $(dirname $(realpath $0))

if [ -e .env ]; then
  . .env
fi

valid_subnet() {
  local ip=$1
  local stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 &&
      ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi

  return $stat
}

docker_iptables_interface_dump() {
  echo docker_iptables_interface_dump $@
}

docker_iptables_interface_allow() {
  echo "Adding from $1 to $2"
  iptables -I DOCKER-USER -i $1 -o $2 -j ACCEPT
}

docker_iptables_interface_delete() {
  echo "Deleting from $1 to $2"
  iptables -D DOCKER-USER -i $1 -o $2 -j ACCEPT
}

upnp_add() {
  if [ "$UPNP_ENABLED" = "YES" ]; then
    upnpc -e "${HOSTNAME} - $1" -r $2 $2 $3 || true
  fi
}

upnp_remove() {
  if [ "$UPNP_ENABLED" = "YES" ]; then
    upnpc -e "${HOSTNAME} - $1" -d $2 $3 || true
  fi
}

routes_add() {
  echo "Adding route for $1"

  ip route add $1 via $2
}

routes_remove() {
  echo "Removing route for $1"

  ip route delete $1 via $2
}

compose_handle() {
  RES=$?

  if [ $RES != 0 ]; then
    echo "docker-compose: unknown error: $RES"
    exit $RES
  fi
}

compose_attach() {
  echo "Attaching to containers..."

  docker-compose up --remove-orphans

  compose_handle
}

compose_start() {
  echo "Starting containers"

  docker-compose up -d --remove-orphans

  compose_handle
}

compose_stop() {
  echo "Stopping containers"

  docker-compose down -v --remove-orphans

  compose_handle
}

compose_get_interfaces() {
  DEFAULTINTERFACE=$(ip route | egrep default | egrep dev | perl -pe 's/.*\ dev\ (.*)\ proto\ .*/$1/g')

  SUBNETS=$(docker-compose config | egrep 'IP|SUBNET' | sort -u | awk '{ print $2 }' | tr ',' '\n' | egrep -v :: | sort -u | cut -f1 -d'/' | xargs)

  INTERFACES=""

  for SUBNET in ${SUBNETS}; do
    IF=$(ip route get ${SUBNET} | egrep dev | perl -pe 's/.*\ dev\ (.*)\ src\ .*/$1/g')

    if [ "$(echo "${INTERFACES}" | egrep "${IF}")" = "" ]; then
      INTERFACES="${INTERFACES} ${IF}"
    fi
  done

  for IIF in ${INTERFACES}; do
    for OIF in ${INTERFACES}; do
      if [ "${IIF}" != "${OIF}" ]; then
        $1 ${IIF} ${OIF}
      fi
    done
  done
}

compose_get_ports() {
  docker-compose config | egrep SERVER_PORT | awk '{ print $2 }' | cut -f2 -d"'" | while read PORTDEF; do

    IF_NAME=$(docker-compose config | egrep 'container_name|SERVER_PORT' | egrep -B 1 ${PORTDEF} | egrep container_name | awk '{ print $2 }')

    $1 ${IF_NAME} ${PORTDEF} UDP
  done
}

compose_get_routes() {
  docker-compose config --services | while read CONTAINER; do
    CONTAINER_INFO=$(docker-compose config | egrep 'container_name|REMOTE_SUBNETS|PEER_._SUBNETS|ipv4_address' | sed 's/=/: /g;s/\-//g' | awk '{ print $1 " " $2 }' | egrep -A 3 ${CONTAINER} | tr '\n' '#')

    SUBNETS=$(echo ${CONTAINER_INFO} | tr '#' '\n' | egrep 'REMOTE_SUBNETS|PEER_._SUBNETS' | awk '{ print $2 }' | xargs | tr ' ' ',')
    GATEWAYV4=$(echo ${CONTAINER_INFO} | tr '#' '\n' | egrep ipv4_address | awk '{ print $2 }')

    echo ${SUBNETS} | tr ',' '\n' | while read SUBNET; do
      if valid_subnet ${SUBNET}; then
        $1 ${SUBNET} ${GATEWAYV4}
      fi
    done
  done
}

lib() {
  echo ""
  echo "Usage:"
  echo ""
  echo "ln -s $(basename $0) <command>"
  echo ""
}

attach() {
  echo "Attaching..."

  compose_start
  compose_get_ports upnp_add
  compose_get_routes routes_add
  compose_attach
}

start() {
  echo "Starting..."

  compose_start
  compose_get_ports upnp_add
  compose_get_routes routes_add
  compose_get_interfaces docker_iptables_interface_allow
}

stop() {
  echo "Stopping..."

  compose_get_interfaces docker_iptables_interface_delete
  compose_get_ports upnp_remove
  compose_get_routes routes_remove
  compose_stop
}

restart() {
  echo "Restarting..."

  ./stop
  ./start
}

check() {
  echo "Checking..."

  docker-compose ps
}

monitor() {
  echo "Monitoring..."

  docker-compose logs -f
}

CMD=$(basename $0 | sed 's/\.sh//g')

if [ "${CMD}" != "lib" ]; then
  $CMD
fi
