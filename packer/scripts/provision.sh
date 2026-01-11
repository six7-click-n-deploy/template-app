#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# TEMPLATE Provisioning Script
# Beispiel: Simple Node.js Web Application
# 
# ANPASSEN: Ersetze dies mit deiner eigenen App-Installation
# -----------------------------------------------------------------------------

echo "=========================================="
echo "Starting provisioning for template app..."
echo "=========================================="

echo "Waiting for cloud-init (if present)..."
cloud-init status --wait || true

# System Update & Upgrade
echo "[1/5] Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install essential tools
echo "[2/5] Installing essential tools..."
sudo apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    build-essential \
    software-properties-common

# Install Node.js (Example - anpassen für deine App!)
echo "[3/5] Installing Node.js runtime..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Setup application directory
echo "[4/5] Setting up application directory..."
sudo mkdir -p /opt/app
sudo chown ubuntu:ubuntu /opt/app

# Create example app (anpassen für deine App!)
cat <<'APPEOF' | sudo tee /opt/app/server.js >/dev/null
const http = require('http');
const hostname = '0.0.0.0';
const port = 80;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/html');
  res.end(\`
    <!DOCTYPE html>
    <html>
    <head><title>Template App</title></head>
    <body>
      <h1>Template App is Running!</h1>
      <p>This is a placeholder. Replace with your actual application.</p>
      <p>Server Time: \${new Date().toISOString()}</p>
    </body>
    </html>
  \`);
});

server.listen(port, hostname, () => {
  console.log(\`Server running at http://\${hostname}:\${port}/\`);
});
APPEOF

sudo chown ubuntu:ubuntu /opt/app/server.js

# Create systemd service
echo "[5/5] Creating systemd service..."
cat <<'SERVICEEOF' | sudo tee /etc/systemd/system/app.service >/dev/null
[Unit]
Description=Template Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Enable service (will start on boot)
sudo systemctl daemon-reload
sudo systemctl enable app.service

# Cleanup
echo "Cleaning up..."
sudo apt-get autoremove -y
sudo apt-get autoclean -y

echo "=========================================="
echo "Provisioning completed successfully!"
echo "=========================================="
echo ""
echo "NEXT STEPS:"
echo "1. This image contains a sample Node.js app on port 80"
echo "2. Replace /opt/app/server.js with your actual application"
echo "3. Modify the systemd service if needed"
echo "4. Deploy infrastructure with Terraform"
echo ""
