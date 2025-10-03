#!/usr/bin/env bash
# Setup Tailscale on Cloud Workstations (no systemd)
# Based on: https://tailscale.com/kb/1147/cloud-gce
set -euo pipefail

echo "==> Installing Tailscale..."
if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
else
  echo "    Tailscale already installed"
fi

echo ""
echo "==> Starting tailscaled in userspace mode..."
if pgrep tailscaled >/dev/null 2>&1; then
  echo "    tailscaled already running"
else
  nohup tailscaled --tun=userspace-networking \
    --socks5-server=localhost:1055 \
    --outbound-http-proxy-listen=localhost:1055 \
    >/tmp/tailscaled.log 2>&1 &
  echo "    Started tailscaled (PID: $!)"
  sleep 2
fi

echo ""
echo "==> Connecting to Tailscale..."
if [ -z "${TAILSCALE_AUTH_KEY:-}" ]; then
  echo "ERROR: TAILSCALE_AUTH_KEY environment variable not set"
  echo "       Export it first: export TAILSCALE_AUTH_KEY=tskey-auth-..."
  exit 1
fi

sudo tailscale up --ssh --accept-dns=false --auth-key="$TAILSCALE_AUTH_KEY"

echo ""
echo "==> Tailscale Status:"
tailscale status

echo ""
echo "==> Tailscale IPs:"
tailscale ip -4
tailscale ip -6 || true

echo ""
echo "==> Setting up auto-start helper..."
mkdir -p ~/bin
cat > ~/bin/tailscale-user-up.sh <<'HELPER'
#!/usr/bin/env bash
set -euo pipefail
pgrep tailscaled >/dev/null 2>&1 || nohup tailscaled --tun=userspace-networking >/tmp/tailscaled.log 2>&1 &
sleep 1
tailscale status >/dev/null 2>&1 || tailscale up --ssh --accept-dns=false
HELPER
chmod +x ~/bin/tailscale-user-up.sh

if ! grep -q "tailscale-user-up.sh" ~/.bashrc; then
  echo '[ -x "$HOME/bin/tailscale-user-up.sh" ] && $HOME/bin/tailscale-user-up.sh' >> ~/.bashrc
  echo "    Added to ~/.bashrc"
else
  echo "    Already in ~/.bashrc"
fi

echo ""
echo "✅ Tailscale setup complete!"
echo ""
echo "Next: Test the Guardian Drill with Tailscale checks:"
echo "  cd /workspace && make drill && cat workstation/receipts/drill-*.json | jq ."
