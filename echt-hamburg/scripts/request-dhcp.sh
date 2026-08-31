#!/usr/bin/env bash
set -euo pipefail

lab_name="echt-hamburg"
for node in support-client it-client webserver management-client; do
  docker exec "clab-${lab_name}-${node}" sh -c 'ip link set eth1 up; udhcpc -i eth1 -n -q'
done
