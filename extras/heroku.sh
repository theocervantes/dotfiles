#!/usr/bin/env bash
# Install the Heroku CLI. Runs INSIDE a VM, as your normal user. Safe to re-run.
#
# This is an extra: bootstrap-dev-vm.sh does not run it. Run it by hand in the
# VMs that need it.
#
#   ~/dotfiles/extras/heroku.sh

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run this as your normal user, not root. It will use sudo where needed." >&2
  exit 1
fi

if command -v heroku >/dev/null; then
  echo "Heroku CLI is already installed."
else
  # Official standalone installer. It installs to /usr/local with sudo and
  # the CLI keeps itself up to date afterwards.
  curl -fsSL https://cli-assets.heroku.com/install.sh | sh
fi

heroku --version

cat <<'NEXT'

Manual step left:
  heroku login        # the Heroku account for THIS VM
NEXT
