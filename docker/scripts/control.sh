#!/bin/bash

. /usr/local/bin/functions.sh

case $1 in
  pre-up)
    echo "Preparing tunnel up"
    saveDefaultRouterV4
    ;;
  up | post-up)
    echo "Brought tunnel up"
    addLocalRoutesV4
    ;;
  pre-down)
    echo "Preparing tunnel down"
    ;;
  down | post-down)
    echo "Brought tunnel down"
    ;;
  *)
    echo "$0 <pre-up|up|post-up|pre-down|down|post-down>"
    ;;
esac
