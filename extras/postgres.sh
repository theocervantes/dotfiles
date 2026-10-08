#!/usr/bin/env bash
# Install PostgreSQL and give your user a database role. Runs INSIDE a VM, as
# your normal user. Safe to re-run.
#
# This is an extra: bootstrap-dev-vm.sh does not run it. Run it by hand in the
# VMs that need it.
#
#   ~/dotfiles/extras/postgres.sh

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Run this as your normal user, not root. It will use sudo where needed." >&2
  exit 1
fi

# The version Ubuntu ships (16 on 24.04). The bootstrap already installs libpq-dev.
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql

# The postgres system user cannot read your home directory, so run from /.
cd /

# A superuser role named after you, so local apps can create their own databases.
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$USER'" | grep -q 1; then
  echo "Database role $USER already exists."
else
  sudo -u postgres createuser --superuser "$USER"
  echo "Created database role $USER."
fi

psql --dbname postgres --tuples-only --no-align --command "SELECT 'connected as ' || current_user"

cat <<'NEXT'

No password is set. Connect over the local socket, which trusts your user:
  psql postgres
  In a Rails app, set the database host to /var/run/postgresql
  (for example DATABASE_HOST=/var/run/postgresql in the project's .env).
NEXT
