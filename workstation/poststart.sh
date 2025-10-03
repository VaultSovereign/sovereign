#!/usr/bin/env bash
set -euo pipefail
echo "[poststart] syncing dotfiles and env"

# Dotfiles (optional: replace with your repo)
if [ ! -d "$HOME/.dotfiles" ]; then
  git clone https://github.com/VaultSovereign/dotfiles "$HOME/.dotfiles" || true
fi
[ -d "$HOME/.dotfiles" ] && (cd "$HOME/.dotfiles" && ./install.sh || true)

# Export pnpm to PATH for shells
grep -q 'PNPM_HOME' ~/.bashrc || cat <<'RC' >> ~/.bashrc
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
RC

# Minimal MOTD
echo "VaultMesh Sovereign Workstation ready $(date)"