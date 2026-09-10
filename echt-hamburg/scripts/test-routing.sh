#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/test-common.sh"
require_lab

# Alle zwölf gerichteten Verbindungen prüfen, nicht nur Router-Adressen.
for index in "${!nodes[@]}"; do
  source_node="${nodes[$index]}"
  check "$source_node -> eigenes Gateway" docker exec "clab-${lab_name}-${source_node}" \
    ping -I eth1 -c 2 -W 2 "${gateways[$index]}"
  for target in "${nodes[@]}"; do
    [[ "$source_node" == "$target" ]] && continue
    if ! address="$(client_ip "$target")" || [[ -z "$address" ]]; then
      printf 'FEHLER: Keine eth1-Adresse für %s. Zuerst request-dhcp.sh ausführen.\n' "$target" >&2
      failed=1
      continue
    fi
    check "$source_node -> $target ($address) über eth1" \
      docker exec "clab-${lab_name}-${source_node}" ping -I eth1 -c 2 -W 2 "$address"
  done
done
exit "$failed"
