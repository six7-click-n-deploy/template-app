#cloud-config

# ── bootcmd: läuft vor write_files ────────────────────────────────────────────
# Verzeichnisse anlegen die write_files benötigt.
# bootcmd läuft sehr früh — nur einfache Shell-Befehle verwenden.
bootcmd:
  - mkdir -p /etc/myapp/users
  - chown root:root /etc/myapp /etc/myapp/users
  - chmod 750 /etc/myapp /etc/myapp/users

# ── write_files: Dateien auf der VM ablegen ────────────────────────────────────
# Nur Datendateien — kein eingebettetes Bash-Script.
# Komplexe Scripts gehören ins Packer-Image (/usr/local/bin/).
write_files:

# Optional: mitgegebene Dateien (assignment_files) ablegen
%{ for slot_key, file in assignment_files ~}
  - path: '/tmp/assignment/${file.name}'
    permissions: '0644'
    owner: 'root:root'
    encoding: b64
    content: '${file.content_b64}'
%{ endfor ~}

# Pro User eine .env-Datei mit Zugangsdaten
# Wichtig: owner 'root:<service-user>' + permissions '0640'
# damit der laufende Dienst die Datei lesen kann (nicht root:root 0600)
%{ for user in team_users ~}
  - path: '/etc/myapp/users/${replace(replace(user.email, "@", "_at_"), ".", "-")}.env'
    permissions: '0640'
    owner: 'root:myapp'
    content: |
      EMAIL=${user.email}
      USERNAME=${user.username}
      PASSWORD=${user.password}
%{ endfor ~}

# ── runcmd: Provision-Script ausführen ────────────────────────────────────────
# Nur eine Zeile — Doppelpunkte außerhalb von Strings brechen das YAML-Parsing.
# Das Script muss im Packer-Image unter /usr/local/bin/ vorhanden sein.
runcmd:
  - bash /usr/local/bin/myapp-provision.sh > /var/log/myapp-provision.log 2>&1