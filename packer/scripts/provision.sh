#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# TEMPLATE Provisioning Script
# Ziel: Hier kommt *deine* App/Runtime rein.
#
# Regeln:
# - idempotent schreiben (mehrfaches Ausführen darf nicht kaputt machen)
# - keine Secrets hardcoden (nutze CI, Vault, cloud-init, env vars, etc.)
# - am Ende: Service läuft / Artefakte liegen / Ports passen zur SG
# -----------------------------------------------------------------------------

echo "Waiting for cloud-init (if present)..."
cloud-init status --wait || true

# Baseline (optional):
# - Updates / Base-Pakete
# - Logs/Debug
echo "Updating package lists..."
sudo apt-get update

# -----------------------------------------------------------------------------
# [1] Runtime installieren (Beispiele, NICHT ausfüllen):
# - apt-get install -y <packages>
# - docker + compose
# - language runtime (node/go/java/python/...)
# -----------------------------------------------------------------------------
# echo "Install runtime..."
# sudo DEBIAN_FRONTEND=noninteractive apt-get install -y <your-packages>

# -----------------------------------------------------------------------------
# [2] App-Artefakt auf die VM bringen (Beispiele):
# - aus Image-Context kopieren (files provisioner) -> dann hier entpacken
# - git clone (nur wenn du damit leben kannst)
# - download aus Artifact Repo (curl/wget)
# -----------------------------------------------------------------------------
# echo "Deploy application files..."
# sudo mkdir -p /opt/app
# sudo tar -xzf /tmp/app.tar.gz -C /opt/app

# -----------------------------------------------------------------------------
# [3] Konfiguration + systemd service erstellen (Beispiele):
# - /etc/<app>/*
# - /etc/systemd/system/<app>.service
# -----------------------------------------------------------------------------
# echo "Configure systemd service..."
# sudo tee /etc/systemd/system/myapp.service >/dev/null <<'EOF'
# [Unit]
# Description=My App
# After=network-online.target
# Wants=network-online.target
#
# [Service]
# Type=simple
# WorkingDirectory=/opt/app
# ExecStart=/opt/app/myapp
# Restart=always
# RestartSec=2
#
# [Install]
# WantedBy=multi-user.target
# EOF
#
# sudo systemctl daemon-reload
# sudo systemctl enable --now myapp.service

# -----------------------------------------------------------------------------
# [4] Optional: Reverse Proxy / TLS / Firewall
# - nginx/caddy/traefik etc. (hier bewusst nur als Platz)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# [5] Cleanup (optional, wenn du kleinere Images willst)
# -----------------------------------------------------------------------------
# sudo apt-get clean
# sudo rm -rf /var/lib/apt/lists/*

echo "Provisioning finished (template)."
