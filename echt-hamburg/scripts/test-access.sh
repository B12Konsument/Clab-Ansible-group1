#!/usr/bin/env bash
# Positive Kontrollen verhindern, dass fehlende Dienste als ACL-Erfolg zählen.
source "$(dirname -- "${BASH_SOURCE[0]}")/test-common.sh"
require_lab
listener_nodes=() listener_files=()
test_id="echt-hamburg-acl-$$"
wan_route_added=0
cleanup() {
  for index in "${!listener_nodes[@]}"; do
    docker exec "clab-${lab_name}-${listener_nodes[$index]}" sh -c \
      'if [ -f "$1" ]; then kill "$(cat "$1")"; rm -f "$1"; fi' \
      sh "${listener_files[$index]}" >/dev/null 2>&1 || true
  done
  if (( wan_route_added )); then
    docker exec "clab-${lab_name}-internet" ip route del "$webserver_ip/32" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

tcp_open() {
  docker exec "clab-${lab_name}-$1" nc -z -w 2 "$2" "$3"
}
tcp_blocked() {
  if tcp_open "$@"; then
    printf 'Unerwartet erreichbar: %s -> %s:%s\n' "$1" "$2" "$3" >&2
    return 1
  fi
}
start_listener() {
  local node="$1" port="$2" pidfile="/tmp/$test_id-$1-$2.pid"
  # Bestehende Dienste nicht ersetzen oder beim Aufräumen beenden.
  if tcp_open "$node" 127.0.0.1 "$port"; then
    printf 'Port %s auf %s ist bereits belegt; kein isolierter Test möglich.\n' "$port" "$node" >&2
    return 1
  fi
  listener_nodes+=("$node") listener_files+=("$pidfile")
  docker exec -d "clab-${lab_name}-$node" sh -c \
    'echo $$ > "$1"; exec nc -lk -p "$2" -e cat' sh "$pidfile" "$port"
  for attempt in {1..10}; do
    tcp_open "$node" 127.0.0.1 "$port" && return 0
    sleep 0.1
  done
  return 1
}

router_management="${gateways[3]}"
for index in "${!vlan_ids[@]}"; do
  [[ "${vlan_ids[$index]}" == 99 ]] && router_management="${gateways[$index]}"
done
ssh_banner() {
  docker exec "clab-${lab_name}-$1" sh -c '
    reply=$(printf "SSH-2.0-lab-test\r\n" | nc -w 2 "$1" 22 || true)
    printf "%s\n" "$reply" | grep "^SSH-" >/dev/null
  ' sh "$router_management"
}
check 'Router-SSH aus VLAN99 erreichbar' ssh_banner management-client
for node in support-client it-client webserver; do
  if ssh_banner "$node"; then
    printf 'FEHLER: Router-SSH aus %s erlaubt.\n' "$node" >&2
    failed=1
  else
    printf 'OK: Router-SSH aus %s gesperrt.\n' "$node"
  fi
done

for target in support-client it-client management-client; do
  address="$(client_ip "$target")"
  [[ -n "$address" ]] || { failed=1; continue; }
  for port in 80 443; do
    if ! start_listener "$target" "$port"; then
      failed=1
      continue
    fi
    check "$target:$port lokal erreichbar (Positivkontrolle)" tcp_open "$target" "$address" "$port"
    for source in "${nodes[@]}"; do
      [[ "$source" == "$target" ]] && continue
      check "$source -> $target:$port durch INTER-VLAN-WEB gesperrt" tcp_blocked "$source" "$address" "$port"
    done
  done
done

# Port 443 nur auf TCP-Ebene prüfen; nginx bietet im Lab weiterhin HTTP an.
if start_listener webserver 443; then
  for node in support-client it-client management-client; do
    check "$node -> Webserver:443 erlaubt" tcp_open "$node" "$webserver_ip" 443
  done
  check 'WAN-Portweiterleitung 443 erreicht den Webserver' \
    docker exec "clab-${lab_name}-internet" sh -ec \
    'reply=$(printf "WAN-443\n" | nc -w 2 "$1" 443); [ "$reply" = WAN-443 ]' sh "$public_ip"
else
  failed=1
fi

# Direkten WAN-Verkehr zu einem nachweislich offenen internen Port prüfen.
if start_listener webserver 4444; then
  check 'Webserver:4444 aus Management erreichbar (Positivkontrolle)' tcp_open management-client "$webserver_ip" 4444
  if docker exec "clab-${lab_name}-internet" ip route add "$webserver_ip/32" via "$public_ip" dev eth1; then
    wan_route_added=1
    check 'WAN-IN sperrt neue Verbindungen zu anderen Ports' tcp_blocked internet "$webserver_ip" 4444
  else
    failed=1
  fi
else
  failed=1
fi
exit "$failed"
