#!/usr/bin/env bash
# Bootstrap a dev VM (Ubuntu 24.04 LTS) for Rails + agentic work.
# Runs INSIDE the VM, as your normal user (not root). Safe to re-run.
#
# From a clone:
#   ~/dotfiles/bootstrap-dev-vm.sh
#
# Without a clone (it clones the repo to ~/dotfiles first):
#   curl -fsSL https://raw.githubusercontent.com/<MY_USER>/dotfiles/main/bootstrap-dev-vm.sh | bash

# GitHub account that hosts this repo. Only used when the script has to clone.
GITHUB_USER="<MY_USER>"

# Edit these to taste. Projects should still pin their own versions in mise.toml.
RUBY_VERSION="latest"
NODE_VERSION="lts"
PYTHON_VERSION="latest"

set -euo pipefail

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# Sets DOTFILES_DIR to the repo this script belongs to, cloning it if needed.
find_dotfiles() {
  local script_dir=""
  # BASH_SOURCE is empty when the script is piped in from curl.
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi

  if [[ -n "$script_dir" && -f "$script_dir/config/gitconfig" ]]; then
    DOTFILES_DIR="$script_dir"
  elif [[ -f "$HOME/dotfiles/config/gitconfig" ]]; then
    DOTFILES_DIR="$HOME/dotfiles"
  elif [[ -e "$HOME/dotfiles" ]]; then
    echo "$HOME/dotfiles exists but is not this repo. Move it away and re-run." >&2
    exit 1
  elif [[ "$GITHUB_USER" == "<MY_USER>" ]]; then
    echo "GITHUB_USER is not set at the top of this script, so the repo cannot be cloned." >&2
    exit 1
  else
    git clone "https://github.com/${GITHUB_USER}/dotfiles" "$HOME/dotfiles"
    DOTFILES_DIR="$HOME/dotfiles"
  fi
}

# Symlink $2 -> $1, moving anything already at $2 out of the way first.
link_config() {
  local src="$1" dest="$2"

  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    echo "  ok      $dest"
    return
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    local backup
    backup="$dest.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$dest" "$backup"
    echo "  backup  $dest -> $backup"
  fi

  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  echo "  link    $dest -> $src"
}

# Everything runs from main, called on the last line, so that a download cut
# short by a dropped connection runs nothing at all.
main() {
  if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root. It will use sudo where needed." >&2
    exit 1
  fi

  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"

  # -------------------------------------------------------------------------
  log "System packages"
  sudo apt-get update
  # build-essential and the -dev libraries are still needed for gems with native
  # extensions (pg, nokogiri fallbacks, etc.) and as a fallback if Ruby must compile.
  sudo apt-get install -y \
    git curl ca-certificates gnupg unzip build-essential pkg-config \
    libssl-dev libyaml-dev zlib1g-dev libreadline-dev libffi-dev libgmp-dev \
    libpq-dev libsqlite3-dev sqlite3 \
    ripgrep fd-find fzf jq bat git-delta htop tmux openssh-server

  # Ubuntu ships fd and bat under different names.
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"

  # -------------------------------------------------------------------------
  log "Dotfiles repo"
  find_dotfiles
  echo "  using $DOTFILES_DIR"

  # -------------------------------------------------------------------------
  log "GitHub CLI (official apt repo)"
  if ! command -v gh >/dev/null; then
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y gh
  fi

  # -------------------------------------------------------------------------
  log "mise"
  if ! command -v mise >/dev/null; then
    curl -fsSL https://mise.run | sh
  fi
  touch "$HOME/.bashrc"
  if ! grep -q 'mise activate bash' "$HOME/.bashrc"; then
    # shellcheck disable=SC2016  # written literally; .bashrc expands it later
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> "$HOME/.bashrc"
  fi

  log "Runtimes and tools via mise (precompiled Ruby, falls back to source if none exists)"
  # Precompiled Ruby is mise's default since 2026.8.0; set explicitly so older mise versions match.
  mise settings set ruby.compile false
  mise use -g "ruby@${RUBY_VERSION}" "node@${NODE_VERSION}" "python@${PYTHON_VERSION}"
  mise use -g neovim@latest lazygit@latest

  # -------------------------------------------------------------------------
  log "Claude Code (native installer, auto-updates)"
  if ! command -v claude >/dev/null; then
    curl -fsSL https://claude.ai/install.sh | bash
  fi

  log "herdr"
  if ! command -v herdr >/dev/null; then
    curl -fsSL https://herdr.dev/install.sh | sh
  fi

  # -------------------------------------------------------------------------
  log "Git defaults (included from the repo; name and email stay in ~/.gitconfig)"
  if git config --global --get-all include.path | grep -Fxq "$DOTFILES_DIR/config/gitconfig"; then
    echo "  ok      ~/.gitconfig already includes $DOTFILES_DIR/config/gitconfig"
  else
    git config --global --add include.path "$DOTFILES_DIR/config/gitconfig"
    echo "  include $DOTFILES_DIR/config/gitconfig"
  fi

  # -------------------------------------------------------------------------
  log "Config symlinks"
  link_config "$DOTFILES_DIR/config/nvim" "$HOME/.config/nvim"
  link_config "$DOTFILES_DIR/config/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"

  # -------------------------------------------------------------------------
  log "Done. Versions:"
  for cmd in git gh mise ruby bundle node python nvim lazygit rg fd fzf jq delta claude herdr; do
    printf '  %-8s ' "$cmd"
    if command -v "$cmd" >/dev/null; then
      "$cmd" --version 2>/dev/null | head -n1 || echo "installed"
    else
      echo "NOT FOUND (open a new shell and check again)"
    fi
  done

  cat <<'EOF'

Manual steps left (they need you, not a script):
  1. git config --global user.name  "Your Name"
     git config --global user.email "you@example.com"   # the identity for THIS VM
  2. ssh-keygen -t ed25519 -C "<vm-name>"               # key that lives ONLY on this VM
  3. gh auth login                                      # the GitHub account for this VM; upload the key when asked
  4. claude                                             # log in with the Claude account for this VM
  5. On the host: stop the VM and take a snapshot named "clean-bootstrap".
EOF
}

main "$@"
