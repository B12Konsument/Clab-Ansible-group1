#!/usr/bin/env bash
# Importiert AMD64-Cisco-Images als :latest und passt die Lab-Topologie an.
# Akzeptiert Cisco-CML-Images.zip oder den bereits entpackten gleichnamigen Ordner.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zip_file="$script_dir/Cisco-CML-Images.zip"
images_dir="$script_dir/Cisco-CML-Images/CL-Images"
temporary_dir=""

declare -a image_specs=(
  "Router/CL-Cisco-Router.tar|cl-cisco-router:latest"
  "Switch/containerlab-cisco-switch.tar|containerlab-cisco-switch:latest"
)


if [[ "${1:-}" == "--help" ]]; then
  echo "Aufruf: ./setup-echt-hamburg-images-x86_64.sh [--configure-only]"
  echo "Importiert lokale AMD64-Images aus ZIP/Ordner und stellt die Topologie auf :latest."
  echo "Fuer x86_64-Linux-Hosts, einschliesslich Fedora und Nobara."
  echo "--configure-only: Nur die Topologie anpassen (vom Host-Installer verwendet)."
  exit 0
fi
if (( $# > 1 )) || [[ $# == 1 && "$1" != "--configure-only" ]]; then
  echo "Unbekannte Argumente. Hilfe: $0 --help" >&2
  exit 1
fi
if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "Fehler: Diese Variante benoetigt einen x86_64-Linux-Host." >&2
  exit 1
fi
command -v python3 >/dev/null 2>&1 || {
  echo "Fehler: python3 fehlt. Zuerst setup-fedora-44-x86_64.sh ausfuehren." >&2
  exit 1
}

configure_topology() {
  python3 - "$script_dir/echt-hamburg/echt-hamburg.clab.yml" <<'PYTHON'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
original = path.read_text()
updated = original
for name in ("cl-cisco-router", "containerlab-cisco-switch"):
    pattern = rf"(?m)^(\s*image: *[\"']?{re.escape(name)}:)(?:arm64|aarch64|latest)([\"']? *(?:#.*)?)$"
    updated, count = re.subn(pattern, r"\g<1>latest\g<2>", updated)
    if count != 1:
        sys.exit(f"Fehler: Genau einen bekannten Image-Eintrag fuer {name} erwartet. Topologie bleibt unveraendert.")
if updated != original:
    path.write_text(updated)
print("Topologie eingerichtet: cl-cisco-router:latest und containerlab-cisco-switch:latest")
PYTHON
}

if [[ "${1:-}" == "--configure-only" ]]; then
  configure_topology
  exit 0
fi

check_image_architecture() {
  local platform
  platform="$(docker image inspect --format '{{.Os}}/{{.Architecture}}' "$1")"
  if [[ "$platform" != "linux/amd64" ]]; then
    echo "Fehler: $1 ist $platform; erwartet wird linux/amd64." >&2
    echo "Ein anderer Tag konvertiert die Image-Architektur nicht." >&2
    exit 1
  fi
}

if ! command -v docker >/dev/null 2>&1; then
  echo "Fehler: Docker ist nicht installiert oder nicht im PATH." >&2
  exit 1
fi

docker_arch="$(docker info --format '{{.Architecture}}')"
if [[ "$docker_arch" != "x86_64" && "$docker_arch" != "amd64" ]]; then
  echo "Fehler: Der Docker-Daemon verwendet $docker_arch statt AMD64." >&2
  exit 1
fi

if [[ -f "$zip_file" ]]; then
  if ! command -v unzip >/dev/null 2>&1; then
    echo "Fehler: unzip ist nicht installiert oder nicht im PATH." >&2
    exit 1
  fi

  temporary_dir="$(mktemp -d)"
  trap '[[ -n "$temporary_dir" ]] && rm -rf -- "$temporary_dir"' EXIT
  echo "Entpacke Cisco-CML-Images.zip temporaer ..."
  unzip -q "$zip_file" -d "$temporary_dir"
  images_dir="$temporary_dir/Cisco-CML-Images/CL-Images"
elif [[ ! -d "$images_dir" ]]; then
  echo "Fehler: Cisco-CML-Images.zip oder der Ordner Cisco-CML-Images fehlt." >&2
  echo "Lege eine der beiden Varianten neben dieses Skript." >&2
  exit 1
fi

for image_spec in "${image_specs[@]}"; do
  archive_rel="${image_spec%%|*}"
  image_tag="${image_spec##*|}"
  archive="$images_dir/$archive_rel"

  if [[ ! -f "$archive" ]]; then
    echo "Fehler: Image-Archiv fehlt: $archive" >&2
    echo "Pruefe den Inhalt von Cisco-CML-Images.zip beziehungsweise Cisco-CML-Images." >&2
    exit 1
  fi

  if docker image inspect "$image_tag" >/dev/null 2>&1; then
    check_image_architecture "$image_tag"
    echo "Vorhanden: $image_tag"
    continue
  fi

  echo "Importiere $archive_rel ..."
  load_output="$(docker load --input "$archive")"
  printf '%s\n' "$load_output"

  # Docker nennt nach dem Laden entweder einen Image-Tag oder eine Image-ID.
  # Diese Ausgabe ist verlaesslicher als die Config-ID in manchen OCI-Archiven.
  loaded_ref="$(sed -nE 's/^Loaded image: (.+)$/\1/p' <<< "$load_output" | tail -n 1)"
  loaded_id="$(sed -nE 's/^Loaded image ID: (sha256:[[:xdigit:]]{64})$/\1/p' <<< "$load_output" | tail -n 1)"
  if [[ -n "$loaded_ref" ]]; then
    source_image="$loaded_ref"
  elif [[ -n "$loaded_id" ]]; then
    source_image="$loaded_id"
  else
    echo "Fehler: Docker hat nach dem Import keine Image-ID und keinen Tag gemeldet." >&2
    echo "Docker-Ausgabe siehe oben. Pruefe das Archiv mit: docker image ls --no-trunc" >&2
    exit 1
  fi

  if ! docker image inspect "$source_image" >/dev/null 2>&1; then
    echo "Fehler: Docker meldete $source_image, das Image ist aber nicht auffindbar." >&2
    exit 1
  fi

  check_image_architecture "$source_image"
  docker tag "$source_image" "$image_tag"
  echo "Importiert: $image_tag"
done

echo
configure_topology
echo "Die Cisco-Images sind bereit. Starte das Lab mit:"
echo "  cd echt-hamburg && containerlab deploy -t echt-hamburg.clab.yml"
