#!/usr/bin/env bash
# Gemeinsame Paketinstallation verwenden und das Projekt auf :latest umstellen.
set -euo pipefail
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ "${1:-}" == "--help" ]]; then
  echo "Aufruf: ./setup-fedora-44-x86_64.sh"
  echo "Installiert die Fedora-44-Host-Werkzeuge auf x86_64 und stellt die"
  echo "Cisco-Images der Lab-Topologie auf :latest um. Import danach separat:"
  echo "  ./setup-echt-hamburg-images-x86_64.sh"
  exit 0
fi
if (( $# > 0 )); then
  echo "Unbekannte Argumente. Hilfe: $0 --help" >&2
  exit 1
fi
exec bash "$script_dir/setup-fedora-44.sh" --x86_64
