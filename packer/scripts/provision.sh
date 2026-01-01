#!/usr/bin/env bash
set -euo pipefail

APP_PORT="${APP_PORT:-80}"

echo "Waiting for cloud-init..."
cloud-init status --wait || true

echo "Updating package lists..."
sudo apt-get update

echo "Installing nginx..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
sudo systemctl enable nginx

echo "Writing status endpoint script..."
sudo tee /usr/local/bin/app-status-json >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

hostname="$(hostname -f 2>/dev/null || hostname)"
uptime_pretty="$(uptime -p 2>/dev/null || true)"
load="$(cut -d' ' -f1-3 /proc/loadavg)"
mem="$(free -m | awk 'NR==2{printf "%d/%d MB", $3, $2}')"
disk="$(df -h / | awk 'NR==2{printf "%s used of %s (%s)", $3, $2, $5}')"
ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
[ -z "${ip:-}" ] && ip="unknown"

printf '{\n'
printf '  "hostname": "%s",\n' "$hostname"
printf '  "ip": "%s",\n' "$ip"
printf '  "uptime": "%s",\n' "${uptime_pretty:-unknown}"
printf '  "load": "%s",\n' "$load"
printf '  "memory": "%s",\n' "$mem"
printf '  "disk": "%s"\n' "$disk"
printf '}\n'
EOF
sudo chmod +x /usr/local/bin/app-status-json

echo "Configuring nginx site..."
sudo tee /etc/nginx/sites-available/openstack-app >/dev/null <<EOF
server {
  listen ${APP_PORT} default_server;
  listen [::]:${APP_PORT} default_server;
  server_name _;
  root /var/www/openstack-app;
  index index.html;

  # JSON status endpoint
  location = /api/status {
    default_type application/json;
    add_header Cache-Control "no-store";
    return 200 '';
  }

  # Use njs-free way: run as CGI-like via fast path (simple and robust):
  location = /api/status.json {
    default_type application/json;
    add_header Cache-Control "no-store";
    alias /var/www/openstack-app/status.json;
  }

  location / {
    try_files \$uri \$uri/ /index.html;
  }
}
EOF

# Enable our site
sudo rm -f /etc/nginx/sites-enabled/default || true
sudo ln -sf /etc/nginx/sites-available/openstack-app /etc/nginx/sites-enabled/openstack-app

echo "Writing web app..."
sudo mkdir -p /var/www/openstack-app

# A tiny updater that writes status.json every 2s (no extra deps)
sudo tee /etc/systemd/system/openstack-status-writer.service >/dev/null <<'EOF'
[Unit]
Description=Write instance status JSON for the landing page
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/bash -lc 'while true; do /usr/local/bin/app-status-json > /var/www/openstack-app/status.json.tmp && mv /var/www/openstack-app/status.json.tmp /var/www/openstack-app/status.json; sleep 2; done'
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

sudo tee /var/www/openstack-app/index.html >/dev/null <<'HTML'
<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>OpenStack Node</title>
  <style>
    :root { --bg1:#0b1020; --bg2:#111b3a; --card: rgba(255,255,255,.08); --line: rgba(255,255,255,.14); --txt:#e9eefc; --muted: rgba(233,238,252,.72); }
    * { box-sizing:border-box; }
    body {
      margin:0; min-height:100vh; color:var(--txt);
      font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Arial, "Noto Sans", "Liberation Sans", sans-serif;
      background:
        radial-gradient(1200px 800px at 15% 15%, rgba(120,80,255,.35), transparent 55%),
        radial-gradient(1000px 700px at 85% 25%, rgba(0,210,255,.22), transparent 50%),
        linear-gradient(160deg, var(--bg1), var(--bg2));
      overflow-x:hidden;
    }
    .wrap { max-width: 1020px; margin: 0 auto; padding: 42px 18px 60px; }
    .top { display:flex; gap:18px; align-items:flex-start; justify-content:space-between; flex-wrap:wrap; }
    .badge {
      display:inline-flex; gap:10px; align-items:center;
      padding:10px 12px; border:1px solid var(--line); border-radius:999px;
      background: rgba(255,255,255,.05); backdrop-filter: blur(8px);
      font-size: 13px; color: var(--muted);
    }
    .dot { width:10px; height:10px; border-radius:50%; background: #22c55e; box-shadow: 0 0 18px rgba(34,197,94,.55); }
    h1 { margin: 18px 0 8px; font-size: clamp(28px, 3.4vw, 44px); letter-spacing:-.02em; }
    p.lead { margin:0; color: var(--muted); font-size: 16px; line-height:1.6; max-width: 70ch; }
    .grid { margin-top: 26px; display:grid; grid-template-columns: repeat(12, 1fr); gap: 14px; }
    .card {
      grid-column: span 6;
      padding: 16px 16px 14px;
      border:1px solid var(--line);
      border-radius: 18px;
      background: var(--card);
      backdrop-filter: blur(10px);
      box-shadow: 0 10px 40px rgba(0,0,0,.25);
    }
    .card.big { grid-column: span 12; }
    .k { font-size: 12px; text-transform: uppercase; letter-spacing:.12em; color: rgba(233,238,252,.62); }
    .v { margin-top: 8px; font-size: 20px; font-weight: 650; }
    .row { display:flex; gap:10px; align-items:center; justify-content:space-between; flex-wrap:wrap; }
    code {
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
      background: rgba(0,0,0,.25); border:1px solid rgba(255,255,255,.16);
      padding: 2px 8px; border-radius: 10px; color: rgba(233,238,252,.92);
    }
    .muted { color: var(--muted); }
    .btns { margin-top: 14px; display:flex; gap:10px; flex-wrap:wrap; }
    button {
      border:1px solid rgba(255,255,255,.18);
      background: rgba(255,255,255,.07);
      color: var(--txt);
      border-radius: 12px;
      padding: 10px 12px;
      cursor:pointer;
      font-weight: 600;
    }
    button:hover { background: rgba(255,255,255,.10); }
    .footer { margin-top: 22px; color: rgba(233,238,252,.55); font-size: 13px; }
    @media (max-width: 760px) { .card { grid-column: span 12; } }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="top">
      <div>
        <div class="badge"><span class="dot"></span><span>nginx ist live • OpenStack Instance</span></div>
        <h1>Hallo 👋</h1>
        <p class="lead">
          Diese Seite kommt aus dem Image/Provisioning. Unten siehst du Live-Statusdaten vom System.
        </p>
      </div>
      <div class="badge muted">
        <span>Endpoint:</span> <code id="endpoint">/api/status.json</code>
      </div>
    </div>

    <div class="grid">
      <div class="card big">
        <div class="row">
          <div>
            <div class="k">Hostname</div>
            <div class="v" id="hostname">…</div>
          </div>
          <div class="btns">
            <button id="refresh">Refresh</button>
            <button id="copy">Copy JSON</button>
          </div>
        </div>
        <div class="footer">Tipp: Security Group muss Port 80/APP_PORT erlauben.</div>
      </div>

      <div class="card"><div class="k">IP</div><div class="v" id="ip">…</div></div>
      <div class="card"><div class="k">Uptime</div><div class="v" id="uptime">…</div></div>
      <div class="card"><div class="k">Load</div><div class="v" id="load">…</div></div>
      <div class="card"><div class="k">Memory</div><div class="v" id="memory">…</div></div>
      <div class="card"><div class="k">Disk</div><div class="v" id="disk">…</div></div>
    </div>
  </div>

  <script>
    const endpoint = "/api/status.json";
    const $ = (id) => document.getElementById(id);

    async function load() {
      try {
        const r = await fetch(endpoint, { cache: "no-store" });
        const j = await r.json();
        $("hostname").textContent = j.hostname ?? "unknown";
        $("ip").textContent = j.ip ?? "unknown";
        $("uptime").textContent = j.uptime ?? "unknown";
        $("load").textContent = j.load ?? "unknown";
        $("memory").textContent = j.memory ?? "unknown";
        $("disk").textContent = j.disk ?? "unknown";
        $("endpoint").textContent = endpoint;
        window.__lastJSON = j;
      } catch (e) {
        $("hostname").textContent = "Fehler beim Laden (Security Group? nginx?)";
      }
    }

    $("refresh").addEventListener("click", load);
    $("copy").addEventListener("click", async () => {
      const txt = JSON.stringify(window.__lastJSON || {}, null, 2);
      await navigator.clipboard.writeText(txt);
      $("copy").textContent = "Copied!";
      setTimeout(() => ($("copy").textContent = "Copy JSON"), 900);
    });

    load();
    setInterval(load, 4000);
  </script>
</body>
</html>
HTML

echo "Starting status writer + reloading nginx..."
sudo systemctl daemon-reload
sudo systemctl enable --now openstack-status-writer.service
sudo nginx -t
sudo systemctl restart nginx

echo "Cleanup..."
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

echo "Done. Serving on port ${APP_PORT}."
