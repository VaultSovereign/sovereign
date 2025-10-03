#!/usr/bin/env bash
set -euo pipefail
if [ "$(uname)" = "Darwin" ]; then
  xcode-select --install 2>/dev/null || true
  brew install --quiet git jq gh node pnpm python rustup-init tmux wezterm
  rustup-init -y
else
  sudo apt-get update && sudo apt-get install -y git jq gh nodejs npm tmux
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  curl https://sh.rustup.rs -sSf | sh -s -- -y
fi
echo "Local dev ready."