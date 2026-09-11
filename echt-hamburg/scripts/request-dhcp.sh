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
  dhcp_options=()
  if [[ "$node" == webserver ]]; then
    dhcp_options=(-C -x "0x3d:$webserver_client_id")
  fi
  # DHCP übernimmt Adresse, Maske und Gateway. Spezifische Routen halten
  # Firmenverkehr (einschließlich Antworten) von der Docker-Standardroute fern.
  if docker exec "$container" sh -ec '
    ip link set eth1 up
    gateway="$1"
    own_network="$2"
    public_route="$3"
    route_count="$4"
    shift 4
    # Routen und zusätzliche DHCP-Optionen getrennt übergeben.
    route_list=""
    for unused in $(seq 1 "$route_count"); do
      route_list="$route_list $1"
      shift
    done
    # Alpine ersetzt resolv.conf mit mv; Docker bindet diese Datei separat ein.
    # Zunächst die tatsächlich empfangenen DNS-Optionen in eine normale Datei
    # schreiben und anschließend den Inhalt der eingebundenen Datei aktualisieren.
    mkdir -p /etc/udhcpc
    dns_config="RESOLV_CONF=/tmp/echt-hamburg-resolv.conf"
    if ! grep -qxF "$dns_config" /etc/udhcpc/udhcpc.conf 2>/dev/null; then
      printf "\n%s\n" "$dns_config" >> /etc/udhcpc/udhcpc.conf
    fi
    rm -f /tmp/echt-hamburg-resolv.conf
    udhcpc -i eth1 -n -q -t 15 -T 3 "$@"
    cat /tmp/echt-hamburg-resolv.conf > /etc/resolv.conf
    ip -4 route show default | grep -F "default via $gateway dev eth1"
    ip route replace "$public_route" via "$gateway" dev eth1
    for network in $route_list; do
      # Die direkt angeschlossene Route des eigenen VLANs beibehalten.
      [ "$network" = "$own_network" ] && continue
      ip route replace "$network" via "$gateway" dev eth1
    done
    ip -4 addr show dev eth1
  ' sh "$gateway" "${networks[$index]}/$lan_prefix" "$public_network" "${#lan_routes[@]}" "${lan_routes[@]}" "${dhcp_options[@]}"; then
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
    resolver_config="$(docker exec "$container" cat /etc/resolv.conf)"
    check "$node: DHCP-DNS-Server und Suchdomäne übernommen" \
      python3 - "$project_dir/playbooks/group_vars.yml" "$resolver_config" <<'PYDNS'
import sys, yaml
from pathlib import Path
settings = yaml.safe_load(Path(sys.argv[1]).read_text())
lines = [line.split() for line in sys.argv[2].splitlines()]
servers = [line[1] for line in lines if len(line) == 2 and line[0] == 'nameserver']
valid = servers == settings['dhcp_dns_servers'] and ['search', settings['domain_name']] in lines
if not valid:
    print('FEHLER: Empfangene DHCP-DNS-Optionen weichen vom Adressplan ab.', file=sys.stderr)
sys.exit(0 if valid else 1)
PYDNS
    if [[ "$node" == webserver ]]; then
      check 'Webserver erhält die feste DHCP-Adresse für die Portweiterleitung' \
        test "$(client_ip webserver)" = "$webserver_ip"
    fi
  else
    printf 'DHCP oder Client-Routen fehlgeschlagen: %s. VLAN, Trunk und DHCP-Pool prüfen.\n' "$node" >&2
    failed=1
  fi
done
exit "$failed"
