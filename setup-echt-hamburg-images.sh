#!/usr/bin/env bash
# Importiert die lokalen Cisco-CML-Containerimages fuer das Projekt echt-hamburg.
# Die Images bleiben im nicht versionierten Ordner Cisco-CML-Images/.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
images_dir="$script_dir/Cisco-CML-Images/CL-Images"

declare -a image_specs=(
  "Router/CL-Cisco-Router.tar|cl-cisco-router:arm64"
  "Switch/containerlab-cisco-switch.tar|containerlab-cisco-switch:arm64"
)

if ! command -v docker >/dev/null 2>&1; then
  echo "Fehler: Docker ist nicht installiert oder nicht im PATH." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Fehler: jq ist nicht installiert oder nicht im PATH." >&2
  exit 1
fi

for image_spec in "${image_specs[@]}"; do
  archive_rel="${image_spec%%|*}"
  image_tag="${image_spec##*|}"
  archive="$images_dir/$archive_rel"

  if [[ ! -f "$archive" ]]; then
    echo "Fehler: Image-Archiv fehlt: $archive" >&2
    echo "Lege den Ordner Cisco-CML-Images neben dieses Skript." >&2
    exit 1
  fi

  if docker image inspect "$image_tag" >/dev/null 2>&1; then
    echo "Vorhanden: $image_tag"
    continue
  fi

  echo "Importiere $archive_rel ..."
  docker load --input "$archive"

  config_path="$(tar -xOf "$archive" manifest.json | jq -r '.[0].Config')"
  image_id="sha256:${config_path##*/}"
  if [[ "$config_path" == "null" ]] || ! docker image inspect "$image_id" >/dev/null 2>&1; then
    echo "Fehler: Das importierte Image aus $archive_rel wurde nicht gefunden." >&2
    exit 1
  fi

  docker tag "$image_id" "$image_tag"
  echo "Importiert: $image_tag"
done

echo
echo "Die Cisco-Images sind bereit. Starte das Lab mit:"
echo "  cd echt-hamburg && containerlab deploy -t echt-hamburg.clab.yml"
