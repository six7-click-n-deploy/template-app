#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# TEMPLATE Provisioning Script
# Purpose: Add your app/runtime here.
#
# Rules:
# - Write idempotent steps (running multiple times must not break anything)
# - Do not hardcode secrets (use CI, Vault, cloud-init, env vars, etc.)
# - End state: service running / artifacts in place / ports match security group
# -----------------------------------------------------------------------------

echo "Waiting for cloud-init (if present)..."
cloud-init status --wait || true

# Baseline (optional):
# - Updates / base packages
# - Logs/Debug
echo "Updating package lists..."
sudo apt-get update

# -----------------------------------------------------------------------------
# [1] Install runtime: minimal web server (nginx)
# -----------------------------------------------------------------------------
echo "Installing nginx (if not already installed)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx

echo "Enabling and restarting nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

# -----------------------------------------------------------------------------
# [2] App artifact: simple HTML page
# -----------------------------------------------------------------------------
echo "Deploying simple index.html..."
sudo mkdir -p /var/www/html

sudo tee /var/www/html/index.html >/dev/null << 'EOF'
<html>
  <head>
    <title>myapp2</title>
  </head>
  <body>
    <h1>Hello from myapp2!</h1>
    <p>Built with Packer & deployed with Terraform.</p>
  </body>
</html>
EOF

# -----------------------------------------------------------------------------
# [3] (Optional) custom systemd service
# - not needed here; nginx is sufficient as the web server
# -----------------------------------------------------------------------------
# Example left commented out

# -----------------------------------------------------------------------------
# [4] Optional: Reverse proxy / TLS / firewall
# - not needed for this minimal example
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# [5] Cleanup (optional, reduces image size)
# -----------------------------------------------------------------------------
# sudo apt-get clean
# sudo rm -rf /var/lib/apt/lists/*

echo "Provisioning finished."
