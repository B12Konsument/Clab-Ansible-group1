#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/test-common.sh"
require_lab
for index in "${!nodes[@]}"; do
  node="${nodes[$index]}"
  vlan="${vlan_ids[$index]}"
  container="clab-${lab_name}-${node}"
  printf '\nDHCP: %s (eth1)\n' "$container"
  # Nach der Konfiguration kann der Trunk noch auf STP-Forwarding warten.
  if docker exec "$container" sh -ec '
    ip link set eth1 up
    udhcpc -i eth1 -n -q -t 15 -T 3
    ip -4 addr show dev eth1
  '; then
    # Die Zuordnung folgt dem aktuellen Adressplan. Die Abweichung von
    # 192.168.108.0/24 wird separat in test-configuration.sh geprüft.
    check "$node: Adresse, /24-Maske und Gateway für VLAN $vlan" \
      docker exec "$container" sh -ec '
        ip -4 -o addr show dev eth1 | grep -Eq "inet 192\\.168\\.$1\\.[0-9]+/24 "
        ip -4 route show | grep -Eq "^default via 192\\.168\\.$1\\.1 dev eth1( |$)"
      ' sh "$vlan"
  else
    printf 'DHCP fehlgeschlagen: %s. VLAN, Trunk und DHCP-Pool prüfen.\n' "$node" >&2
    failed=1
  fi
done
exit "$failed"
