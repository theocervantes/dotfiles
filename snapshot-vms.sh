#!/usr/bin/env bash
# Stop every Incus instance and take a dated snapshot of each. Runs on the HOST.
#
#   ./snapshot-vms.sh
#
# Snapshots are named stopped-YYYYMMDD-HHMMSS and Incus deletes them on its own
# after KEEP_FOR. The clean-bootstrap snapshots are never touched.

# How long Incus keeps each snapshot (a time span such as 14d or 12H).
KEEP_FOR="14d"

set -euo pipefail

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

command -v incus >/dev/null || { echo "Error: incus is not installed" >&2; exit 1; }

stamp="$(date +%Y%m%d-%H%M%S)"
names="$(incus list --format csv --columns n)"

if [[ -z "$names" ]]; then
  echo "No instances found."
  exit 0
fi

for name in $names; do
  log "$name"

  state="$(incus list --format csv --columns ns | grep "^$name," | cut -d, -f2)"
  if [[ "$state" == "STOPPED" ]]; then
    echo "  already stopped"
  else
    echo "  stopping (was $state)"
    # A clean shutdown, so the snapshot is not of a half-written disk.
    incus stop "$name" --timeout 120
  fi

  incus snapshot create "$name" "stopped-$stamp" --expiry "$KEEP_FOR"
  echo "  snapshot stopped-$stamp (kept for $KEEP_FOR)"
done

log "Done"
incus list --format compact --columns nsS
