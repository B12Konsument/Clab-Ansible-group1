#!/usr/bin/env bash
# Gemeinsame Hilfsfunktionen; kein eigenständiger Test.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
lab_name="${LAB_NAME:-echt-hamburg}"
nodes=(support-client it-client webserver management-client)
vlan_ids=(10 20 30 99)
failed=0

check() {
  local description="$1"
  shift
  if "$@"; then
    printf 'OK: %s\n' "$description"
  else
    printf 'FEHLER: %s\n' "$description" >&2
    failed=1
  fi
}

client_ip() {
  docker exec "clab-${lab_name}-$1" ip -4 -o addr show dev eth1 |
    awk '{split($4, address, "/"); print address[1]; exit}'
}

require_lab() {
  if ! docker info >/dev/null 2>&1; then
    printf 'Docker ist nicht erreichbar. Docker starten und Zugriffsrechte prüfen.\n' >&2
    exit 1
  fi
}

# Eigenes Inventar: keine Abhängigkeit von DNS oder leeren ansible_host-Feldern
# im generierten Containerlab-Inventar. Die Zugangsdaten werden nicht ausgegeben.
run_playbook() (
  umask 077
  test_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$test_tmp"' EXIT
  export ANSIBLE_LOCAL_TEMP="$test_tmp/local"
  export ANSIBLE_PERSISTENT_CONTROL_PATH_DIR="$test_tmp/pc"
  export ANSIBLE_HOST_KEY_CHECKING=False
  python3 - "$lab_name" "${2:-direct}" >"$test_tmp/inventory.json" <<'PY'
import json, os, shlex, subprocess, sys
lab, mode = sys.argv[1:]
groups = {}
for node, group, vlan_ip in [('r1', 'routers', '192.168.99.1'), ('s1', 'switches', '192.168.99.2')]:
    name = f'clab-{lab}-{node}'
    data = json.loads(subprocess.check_output(['docker', 'inspect', name]))[0]
    addresses = [n['IPAddress'] for n in data['NetworkSettings']['Networks'].values() if n['IPAddress']]
    if not addresses:
        raise SystemExit(f'Keine Docker-Management-IP für {name}')
    host = {'ansible_host': vlan_ip if mode == 'vlan99' else addresses[0]}
    if mode == 'vlan99':
        host['ansible_libssh_proxy_command'] = shlex.join(
            ['docker', 'exec', '-i', f'clab-{lab}-management-client', 'nc', vlan_ip, '22'])
    groups[group] = {'hosts': {node: host}}
print(json.dumps({'all': {'children': groups, 'vars': {
    'ansible_connection': 'ansible.netcommon.network_cli',
    'ansible_network_os': 'cisco.ios.ios',
    'ansible_network_cli_ssh_type': 'libssh',
    'ansible_user': os.environ.get('LAB_USER', 'netadmin'),
    'ansible_password': os.environ.get('LAB_PASSWORD', 'admin'),
    'ansible_connect_timeout': 15,
    'ansible_command_timeout': 30,
    'ansible_network_cli_retries': 1,
}}}))
PY
  cd "$project_dir"
  ansible-playbook -i "$test_tmp/inventory.json" -e @playbooks/group_vars.yml "$1" || exit 1
)
