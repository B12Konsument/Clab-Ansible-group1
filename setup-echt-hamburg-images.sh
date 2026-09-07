#!/usr/bin/env bash
# Importiert die lokalen Cisco-CML-Containerimages fuer das Projekt echt-hamburg.
# Akzeptiert Cisco-CML-Images.zip oder den bereits entpackten gleichnamigen Ordner.

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
zip_file="$script_dir/Cisco-CML-Images.zip"
images_dir="$script_dir/Cisco-CML-Images/CL-Images"
temporary_dir=""

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
