#!/usr/bin/env bash
# Create a dev VM with Incus. Runs on the HOST.
#
#   ./create-vm.sh NAME [--cpu N] [--memory SIZE] [--disk SIZE] [--user NAME]
#
# The VM gets no shared folders and no disk devices from the host. The only
# thing copied in is the committed contents of this repo.

set -euo pipefail

CPU=4
MEMORY=8GiB
DISK=60GiB
VM_USER="$(id -un)"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { echo "Error: $*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 NAME [--cpu N] [--memory SIZE] [--disk SIZE] [--user NAME]

  NAME           name of the new VM (must not exist yet)
  --cpu N        number of CPUs       (default: $CPU)
  --memory SIZE  memory limit         (default: $MEMORY)
  --disk SIZE    root disk size       (default: $DISK)
  --user NAME    user inside the VM   (default: $VM_USER)
EOF
}

# ---------------------------------------------------------------------------
# Arguments

NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --cpu|--memory|--disk|--user)
      [[ $# -ge 2 ]] || die "$1 needs a value"
      case "$1" in
        --cpu)    CPU="$2" ;;
        --memory) MEMORY="$2" ;;
        --disk)   DISK="$2" ;;
        --user)   VM_USER="$2" ;;
      esac
      shift 2
      ;;
    -*) usage >&2; die "unknown option: $1" ;;
    *)
      [[ -z "$NAME" ]] || die "only one VM name is allowed"
      NAME="$1"
      shift
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  usage >&2
  exit 1
fi

[[ "$CPU" =~ ^[0-9]+$ ]] || die "--cpu must be a whole number"
[[ "$VM_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "--user must be a plain lowercase username"
[[ "$VM_USER" != "root" ]] || die "--user must not be root"

# ---------------------------------------------------------------------------
# Checks before anything is created

command -v incus >/dev/null || die "incus is not installed"
command -v git >/dev/null || die "git is not installed"

if incus list --format csv --columns n | grep -Fxq "$NAME"; then
  die "an instance named '$NAME' already exists; refusing to touch it"
fi

git -C "$REPO_DIR" rev-parse --verify --quiet HEAD >/dev/null \
  || die "$REPO_DIR has no commits; commit the repo before creating a VM"

if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
  echo "Note: $REPO_DIR has uncommitted changes. Only the last commit is copied into the VM."
fi

# ---------------------------------------------------------------------------
log "Launching $NAME (cpu=$CPU memory=$MEMORY disk=$DISK)"
incus launch images:ubuntu/24.04 "$NAME" --vm \
  --config limits.cpu="$CPU" \
  --config limits.memory="$MEMORY" \
  --device root,size="$DISK"

# The script adds no devices itself, but a profile could. The root disk must
# be the only disk the VM has.
disk_count="$(incus config show "$NAME" --expanded | grep -c 'type: disk' || true)"
if [[ "$disk_count" -ne 1 ]]; then
  incus stop "$NAME" --force
  die "$NAME has $disk_count disk devices, expected only the root disk. A profile is adding one. The VM is stopped; inspect it with: incus config show $NAME --expanded"
fi

# ---------------------------------------------------------------------------
log "Waiting for the VM to accept commands"
ready=0
for _ in $(seq 1 90); do
  if incus exec "$NAME" -- true >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
[[ "$ready" -eq 1 ]] || die "$NAME did not become ready in 3 minutes; check: incus info $NAME"

# ---------------------------------------------------------------------------
log "Creating user $VM_USER with sudo"
# No password is set, so sudo is passwordless. You enter the VM with incus exec.
incus exec "$NAME" -- bash -s -- "$VM_USER" <<'EOF'
set -euo pipefail
user="$1"
if ! id "$user" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$user"
fi
usermod --append --groups sudo "$user"
echo "$user ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$user"
chmod 0440 "/etc/sudoers.d/90-$user"
EOF

# ---------------------------------------------------------------------------
log "Copying the repo to /home/$VM_USER/dotfiles"
# git archive sends only committed files, so nothing ignored or untracked on
# the host (a stray .env, a key) can end up in the VM.
incus exec "$NAME" -- mkdir -p "/home/$VM_USER/dotfiles"
git -C "$REPO_DIR" archive HEAD | incus exec "$NAME" -- tar -x -C "/home/$VM_USER/dotfiles"
incus exec "$NAME" -- chown -R "$VM_USER:$VM_USER" "/home/$VM_USER/dotfiles"

# ---------------------------------------------------------------------------
log "Done"
cat <<EOF

Next steps:
  1. Open a shell in the VM:
       incus exec $NAME -- su - $VM_USER
  2. Inside the VM:
       ~/dotfiles/bootstrap-dev-vm.sh
  3. Inside the VM, the manual steps the bootstrap prints at the end:
       git name/email, ssh-keygen, gh auth login, claude
  4. Back on the host:
       incus stop $NAME
       incus snapshot create $NAME clean-bootstrap
EOF
