#!/usr/bin/env bash
# Helper script to start Tailscale in userspace mode (for Cloud Workstations without systemd)
# Installation:
#   1. Copy this to ~/bin/tailscale-user-up.sh on your workstation
#   2. chmod +x ~/bin/tailscale-user-up.sh
#   3. Add to ~/.bashrc: [ -x "$HOME/bin/tailscale-user-up.sh" ] && $HOME/bin/tailscale-user-up.sh

set -euo pipefail
pgrep tailscaled >/dev/null 2>&1 || nohup tailscaled --tun=userspace-networking >/tmp/tailscaled.log 2>&1 &
sleep 1
tailscale status >/dev/null 2>&1 || tailscale up --ssh --accept-dns=false
