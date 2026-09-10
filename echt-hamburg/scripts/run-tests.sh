#!/usr/bin/env bash
# Alle fachlichen Prüfungen ausführen und die Ausgaben dauerhaft speichern.
set -uo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
umask 077
log_dir="$project_dir/logs/testlauf-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$log_dir" || exit 1
printf 'Logverzeichnis: %s\n' "$log_dir"
printf 'Skript\tExit-Code\n' > "$log_dir/ergebnisse.tsv"
overall=0
for script in request-dhcp test-configuration test-routing test-management test-nat test-webserver; do
  printf '\nSTART %s.sh\n' "$script" | tee -a "$log_dir/gesamt.log"
  bash "$project_dir/scripts/$script.sh" 2>&1 | tee "$log_dir/$script.log" | tee -a "$log_dir/gesamt.log"
  status=${PIPESTATUS[0]}
  printf '%s.sh\t%s\n' "$script" "$status" >> "$log_dir/ergebnisse.tsv"
  printf 'ENDE %s.sh: Exit-Code %s\n' "$script" "$status" | tee -a "$log_dir/gesamt.log"
  if (( status != 0 )); then overall=1; fi
done
cat "$log_dir/ergebnisse.tsv"
printf '\nAusgaben: %s\n' "$log_dir"
exit "$overall"
