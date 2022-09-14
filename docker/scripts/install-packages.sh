#!/usr/bin/env bash

apt-get update -qq &&
    apt-get install -y --no-install-recommends "$@"

rm -r /var/lib/apt/lists /var/cache/apt/archives
