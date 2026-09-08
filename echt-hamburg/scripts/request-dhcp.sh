#!/usr/bin/env bash
set -euo pipefail

lab_name="echt-hamburg"
failed=0
for node in support-client it-client webserver management-client; do
  container="clab-${lab_name}-${node}"
  printf '\nDHCP: %s (eth1)\n' "$container"
  # Nach der Konfiguration kann der Trunk noch auf STP-Forwarding warten.
  if docker exec "$container" sh -ec '
    ip link set eth1 up
    udhcpc -i eth1 -n -q -t 15 -T 3
    ip -4 addr show dev eth1
  '; then
    printf 'DHCP erfolgreich: %s\n' "$node"
  else
    printf 'DHCP fehlgeschlagen: %s. VLAN, Trunk und DHCP-Pool prüfen.\n' "$node" >&2
    failed=1
  fi
done
exit "$failed"
