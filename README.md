# dotfiles

Provisioning for my personal dev VMs: Ubuntu 24.04 VMs created with
[Incus](https://linuxcontainers.org/incus/) on a host machine. Each VM is a
separate world (one for personal projects, one for contract work) and only one
runs at a time. Everything here is plain bash.

**This repo is public. Never commit keys, tokens, client names, or contract
details.** Identity and credentials are set by hand inside each VM and stay
there.

## Layout

    bootstrap-dev-vm.sh   runs INSIDE a VM, as a normal user
    create-vm.sh          runs on the HOST
    config/
      gitconfig           shared git defaults, no name or email
      nvim/               Neovim config
      claude/CLAUDE.md    global coding standards for Claude Code

## Creating a VM (on the host)

    ./create-vm.sh NAME [--cpu 4] [--memory 8GiB] [--disk 60GiB] [--user NAME]

This launches `images:ubuntu/24.04` as a VM with those limits, waits for it to
come up, creates the user with passwordless sudo, and copies the last commit
of this repo to `~/dotfiles` in the VM. The user defaults to your host
username.

It refuses to run if an instance with that name already exists. It adds no
shared folders and no host disk devices, and stops the VM if a profile added
one.

The copy in the VM is a plain export of the last commit, not a git clone, so
nothing untracked on the host can leak in. Uncommitted changes are not copied.

Then open a shell in the VM:

    incus exec NAME -- su - USER

Stop one VM before starting the other:

    incus stop OTHER
    incus start NAME

## Bootstrapping (inside the VM)

If `create-vm.sh` made the VM, the repo is already there:

    ~/dotfiles/bootstrap-dev-vm.sh

From a clone you made yourself:

    git clone https://github.com/<MY_USER>/dotfiles ~/dotfiles
    ~/dotfiles/bootstrap-dev-vm.sh

Or as a one-liner, which clones the repo to `~/dotfiles` first:

    curl -fsSL https://raw.githubusercontent.com/<MY_USER>/dotfiles/main/bootstrap-dev-vm.sh | bash

The script installs apt packages, the GitHub CLI, mise (Ruby, Node, Python,
Neovim, lazygit), Claude Code, and herdr. It then:

- adds `config/gitconfig` as an include in `~/.gitconfig`;
- symlinks `config/nvim` to `~/.config/nvim`;
- symlinks `config/claude/CLAUDE.md` to `~/.claude/CLAUDE.md`.

Anything already at those paths is moved to `<path>.bak.<timestamp>` first.
The script is safe to re-run.

## Manual steps

These stay manual on purpose. Do them inside each VM, with the identity that
belongs to that VM.

1. Git identity:

       git config --global user.name  "Your Name"
       git config --global user.email "you@example.com"

2. An SSH key that lives only on this VM:

       ssh-keygen -t ed25519 -C "<vm-name>"

3. GitHub login, with the account for this VM:

       gh auth login

4. Claude Code login, with the account for this VM:

       claude

5. On the host, stop the VM and snapshot it:

       incus stop NAME
       incus snapshot create NAME clean-bootstrap

   To go back to it later: `incus snapshot restore NAME clean-bootstrap`.
