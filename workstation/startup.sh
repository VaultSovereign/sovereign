#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[startup] $*"; }

log "System update"
sudo apt-get update -y && sudo apt-get install -y unzip git jq build-essential

log "Node + pnpm"
curl -fsSL https://get.pnpm.io/install.sh | sh -
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
. "$HOME/.nvm/nvm.sh" && nvm install 20 && corepack enable

log "Rust"
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"

log "Python"
sudo apt-get install -y python3-venv pipx && pipx ensurepath

log "Google CLI already present on Workstations; verify ADC"
gcloud config set project "${PROJECT_ID}"

log "WezTerm/tmux/zsh minimal (optional)"
sudo apt-get install -y tmux zsh