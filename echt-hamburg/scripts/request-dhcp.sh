#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/test-common.sh"
require_lab
lan_routes=()
for network in "${networks[@]}"; do
  lan_routes+=("$network/$lan_prefix")
done
for index in "${!nodes[@]}"; do
  node="${nodes[$index]}"
  vlan="${vlan_ids[$index]}"
  gateway="${gateways[$index]}"
  container="clab-${lab_name}-${node}"
  printf '\nDHCP: %s (eth1)\n' "$container"
  # DHCP übernimmt Adresse, Maske und Gateway. Spezifische Routen halten
  # Firmenverkehr (einschließlich Antworten) von der Docker-Standardroute fern.
  if docker exec "$container" sh -ec '
    ip link set eth1 up
    udhcpc -i eth1 -n -q -t 15 -T 3
    ip -4 route show default | grep -F "default via $1 dev eth1"
    gateway="$1"
    own_network="$2"
    ip route replace "$3" via "$gateway" dev eth1
    shift 3
    for network in "$@"; do
      # Die direkt angeschlossene Route des eigenen VLANs beibehalten.
      [ "$network" = "$own_network" ] && continue
      ip route replace "$network" via "$gateway" dev eth1
    done
    ip -4 addr show dev eth1
  ' sh "$gateway" "${networks[$index]}/$lan_prefix" "$public_network" "${lan_routes[@]}"; then
    address_info="$(docker exec "$container" ip -4 -o addr show dev eth1)"
    check "$node: DHCP-Hostadresse und /$lan_prefix-Maske für VLAN $vlan" \
      python3 - "${networks[$index]}/$lan_prefix" "$gateway" "$address_info" <<'PY'
from ipaddress import IPv4Interface, IPv4Network
import sys
network = IPv4Network(sys.argv[1])
addresses = [IPv4Interface(line.split()[3]) for line in sys.argv[3].splitlines() if ' inet ' in line]
valid = len(addresses) == 1 and addresses[0].network == network and str(addresses[0].ip) != sys.argv[2] and addresses[0].ip not in (network.network_address, network.broadcast_address)
if not valid:
    print(f'FEHLER: Erwartet wird eine DHCP-Hostadresse aus {network}, erhalten: {addresses}', file=sys.stderr)
sys.exit(0 if valid else 1)
PY
  else
    printf 'DHCP oder Client-Routen fehlgeschlagen: %s. VLAN, Trunk und DHCP-Pool prüfen.\n' "$node" >&2
    failed=1
  fi
done
exit "$failed"
