#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/test-common.sh"
require_lab
export NAT_CLIENT_IPS=""
for node in "${nodes[@]}"; do
  if ! address="$(client_ip "$node")" || [[ -z "$address" ]]; then
    printf 'FEHLER: Keine eth1-Adresse für %s. Zuerst request-dhcp.sh ausführen.\n' "$node" >&2
    failed=1
    continue
  fi
  NAT_CLIENT_IPS+="$address "
  check "$node -> simuliertes Internet über eth1" \
    docker exec "clab-${lab_name}-${node}" ping -I eth1 -c 2 -W 2 200.108.1.2
done
# Unmittelbar nach den Pings die ICMP-Übersetzungen prüfen.
check 'NAT/PAT: private Quelladressen werden zu 200.108.1.1 übersetzt' \
  run_playbook playbooks/tests/nat.yml
exit "$failed"
