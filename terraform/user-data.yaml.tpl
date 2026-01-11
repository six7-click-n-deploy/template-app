#cloud-config

# Team-Gruppen erstellen
groups:
%{ for team in teams ~}
  - ${team}
%{ endfor ~}

# User-Accounts erstellen
users:
%{ for user_id, user in users ~}
  - name: ${user.username}
    groups: ${user.team}
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
%{ endfor ~}

# Passwörter setzen (chpasswd funktioniert zuverlässig)
chpasswd:
  list: |
%{ for user_id, user in users ~}
    ${user.username}:${passwords[user_id]}
%{ endfor ~}
  expire: false

# SSH Passwort-Authentifizierung aktivieren
ssh_pwauth: true
