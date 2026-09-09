#!/usr/bin/env bash
source "$(dirname -- "${BASH_SOURCE[0]}")/test-common.sh"
require_lab
if ! address="$(client_ip webserver)" || [[ -z "$address" ]]; then
  printf 'FEHLER: Keine Webserver-Adresse auf eth1. Zuerst request-dhcp.sh ausführen.\n' >&2
  exit 1
fi

test_tmp="$(mktemp -d)"
trap 'rm -rf -- "$test_tmp"' EXIT
fetch_page() {
  docker exec "clab-${lab_name}-$1" sh -ec '
    ip route get "$1" | grep -q "dev eth1 " || {
      echo "Keine Route zum Webserver über eth1; Client-Routing prüfen." >&2
      exit 1
    }
    wget -T 10 -q -O /dev/null "http://$1/"
  ' sh "$address"
}
for node in support-client it-client management-client; do
  check "HTTP von $node zur Website über das Firmennetz" fetch_page "$node"
done

# Den tatsächlich ausgelieferten Inhalt auch bei einem Routingfehler prüfen.
fetch_local_page() {
  docker exec "clab-${lab_name}-webserver" wget -T 10 -q -O - http://127.0.0.1/ >"$test_tmp/webserver.html"
}
check 'Webserver liefert lokal eine HTTP-Seite aus' fetch_local_page

check 'Website enthält Filiale, Gruppenname und alle angegebenen Mitglieder' \
  python3 - "$project_dir/playbooks/group_vars.yml" "$test_tmp" <<'PY'
from html.parser import HTMLParser
from pathlib import Path
import sys
import yaml

class PageText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
    def handle_data(self, data):
        self.parts.append(data)

settings = yaml.safe_load(Path(sys.argv[1]).read_text())
members = settings.get('group_members', [])
failed = False
if not isinstance(members, list) or not members or not all(isinstance(m, str) and m.strip() for m in members):
    print('FEHLER: group_members in playbooks/group_vars.yml als Liste der echten Namen ergänzen; Mitgliedernachweis fehlt.', file=sys.stderr)
    members = []
    failed = True
expected = [settings['franchise_name'], settings['group_name'], *members]
for page in sorted(Path(sys.argv[2]).glob('*.html')):
    parser = PageText()
    parser.feed(page.read_text())
    content = ' '.join(' '.join(parser.parts).split())
    missing = [name for name in expected if ' '.join(name.split()) not in content]
    if missing:
        print(f'FEHLER: {page.stem}: Website enthält nicht: {", ".join(missing)}', file=sys.stderr)
        failed = True
sys.exit(int(failed))
PY
exit "$failed"
