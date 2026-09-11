#!/usr/bin/env bash
# Gemeinsame Hilfsfunktionen; kein eigenständiger Test.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
lab_name="${LAB_NAME:-echt-hamburg}"
# Ein gemeinsamer Adressplan für Konfiguration und Funktionsprüfungen.
settings="$(python3 - "$project_dir/playbooks/group_vars.yml" <<'PYSETTINGS'
import sys, yaml
from pathlib import Path
s = yaml.safe_load(Path(sys.argv[1]).read_text())
print(s['lan_prefix'], s['public_network'], s['public_peer'], s['public_ip'], s['webserver_ip'], s['webserver_client_id'].replace('.', ''), sep='\t')
for v in s['vlans']:
    print(v['node'], v['id'], v['network'], v['gateway'], sep='\t')
PYSETTINGS
)"
{
  IFS=$'\t' read -r lan_prefix public_network public_peer public_ip webserver_ip webserver_client_id
  nodes=() vlan_ids=() networks=() gateways=()
  while IFS=$'\t' read -r node vlan network gateway; do
    nodes+=("$node") vlan_ids+=("$vlan") networks+=("$network") gateways+=("$gateway")
  done
} <<< "$settings"
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

# Alle Cisco-Prüfungen laufen über die festen VLAN99-Adressen. Nach erneutem
# Deployment können Docker-Adressen von gespeicherten IOS-Adressen abweichen
# und sogar auf das falsche Gerät führen. Zugangsdaten werden nicht ausgegeben.
run_playbook() (
  umask 077
  test_tmp="$(mktemp -d)"
  trap 'rm -rf -- "$test_tmp"' EXIT
  export ANSIBLE_LOCAL_TEMP="$test_tmp/local"
  export ANSIBLE_PERSISTENT_CONTROL_PATH_DIR="$test_tmp/pc"
  export ANSIBLE_HOST_KEY_CHECKING=False
  python3 - "$lab_name" "$project_dir/playbooks/group_vars.yml" >"$test_tmp/inventory.json" <<'PY'
import json, os, shlex, sys, yaml
from pathlib import Path
lab = sys.argv[1]
settings = yaml.safe_load(Path(sys.argv[2]).read_text())
router_ip = next(v['gateway'] for v in settings['vlans'] if v['id'] == 99)
groups = {}
for node, group, vlan_ip in [('r1', 'routers', router_ip), ('s1', 'switches', settings['switch_management_ip'])]:
    host = {'ansible_host': vlan_ip}
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
