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
    snapshot-vms.sh       runs on the HOST
    extras/               optional installers, run by hand INSIDE a VM
    config/
      gitconfig           shared git defaults, no name or email
      nvim/               Neovim config (LazyVim)
      claude/CLAUDE.md    global coding standards for Claude Code

## Host setup (once)

The host needs Incus with VM support and nothing else from this repo:

1. Install Incus from your distribution's packages.
2. Add yourself to the `incus-admin` group, then log out and back in.
3. Run `incus admin init --minimal`.

## Creating a VM (on the host)

    ./create-vm.sh NAME [--cpu 4] [--memory 4GiB] [--disk 60GiB] [--user NAME]

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

    git clone https://github.com/theocervantes/dotfiles ~/dotfiles
    ~/dotfiles/bootstrap-dev-vm.sh

Or as a one-liner, which clones the repo to `~/dotfiles` first:

    curl -fsSL https://raw.githubusercontent.com/theocervantes/dotfiles/main/bootstrap-dev-vm.sh | bash

The script installs apt packages, the GitHub CLI, mise (Ruby, Node, Python,
Neovim, lazygit), Claude Code, herdr with its Claude Code integration, and the
Playwright CLI with Google Chrome. It then:

- adds `config/gitconfig` as an include in `~/.gitconfig`;
- symlinks `config/nvim` to `~/.config/nvim`;
- symlinks `config/claude/CLAUDE.md` to `~/.claude/CLAUDE.md`.

Anything already at those paths is moved to `<path>.bak.<timestamp>` first.
The script is safe to re-run.

When it finishes, leave the VM shell and open a new one. The tools it
installed are not on your `PATH` until you do.

### Updating a VM later

The copy `create-vm.sh` leaves in the VM has no git history, so it cannot
pull. Replace it with a clone once; the symlinks keep working because the
path is the same:

    rm -rf ~/dotfiles && git clone https://github.com/theocervantes/dotfiles ~/dotfiles

After that, `git -C ~/dotfiles pull` and re-run the bootstrap.

## Neovim

`config/nvim` is a [LazyVim](https://www.lazyvim.org/) setup with two
additions. The first launch of `nvim` installs the plugins.

- [vim-vertigo](https://github.com/prendradjaja/vim-vertigo) jumps by relative
  line number, typed on the Colemak-DH home row (`arstgmneio` for
  `1234567890`). `<Space>e` jumps down and `<Space>n` jumps up. These replace
  LazyVim's file explorer and notification history on the same keys; the
  explorer is still on `<Space>E`.
- `kk` leaves insert and visual mode.

`lazy-lock.json` pins the plugin versions. Updating plugins inside a VM
rewrites it in that VM's clone, so commit it from there or discard the change
before the next pull.

## Extras

Tools that only some VMs need live in `extras/`, one script each. The
bootstrap does not run them. Run the ones a VM needs by hand, after the
bootstrap:

    ~/dotfiles/extras/heroku.sh

Each is safe to re-run. To add one, copy an existing script. Run a VM's
extras before taking its snapshot.

Where things go:

- every VM needs it: `bootstrap-dev-vm.sh`;
- a generic tool only some VMs need: `extras/`;
- anything that names or describes a client or contract: not in this repo.
  It stays inside that VM, or in the project's own repo.

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
   To replace it with a newer one, add `--reuse` to the create command.

## Shutting down for the day (on the host)

    ./snapshot-vms.sh

This stops every Incus instance that is running and takes a snapshot of each,
named `stopped-<date>-<time>`. Incus deletes those on its own after 14 days
(`KEEP_FOR` at the top of the script). `clean-bootstrap` is never touched.

An alias in the host's `~/.bashrc` makes it one word:

    alias vms-down="$HOME/path/to/dotfiles/snapshot-vms.sh"

## Attaching herdr from the host (optional)

`herdr --remote` reaches the VM over SSH, so the host needs a key in the VM
and an address that does not change. Run these on the host, with the VM
running. `VM_IP` is the address `incus list` shows for it.

1. Put a host public key in the VM. Only the public key goes in; do not use
   SSH agent forwarding, which would let the VM use the host's keys.

       incus exec NAME -- su - USER -c 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys' < ~/.ssh/id_ed25519.pub

2. Pin the VM's address so it survives restarts:

       incus config device override NAME eth0 ipv4.address=VM_IP

3. Give the VM a short name in the host's `~/.ssh/config`:

       Host NAME-vm
           HostName VM_IP
           User USER
           ForwardAgent no

4. Attach:

       herdr --remote NAME-vm

Detach with `Ctrl+b` then `q`. The session keeps running in the VM.
