#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/test-common.sh"
require_lab
# SSH wird durch nc im Management-Client zu den VLAN99-Adressen geführt.
# Damit beweist eine erfolgreiche Anmeldung den vorgesehenen Management-Pfad.
run_playbook playbooks/tests/management.yml
