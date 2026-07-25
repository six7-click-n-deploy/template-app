#cloud-config

# ── bootcmd: runs before write_files ──────────────────────────────────────────
# Create directories required by write_files.
# bootcmd runs very early — use only simple shell commands.
bootcmd:
  - mkdir -p /etc/myapp/users
  - chown root:root /etc/myapp /etc/myapp/users
  - chmod 750 /etc/myapp /etc/myapp/users

# ── write_files: place files on the VM ────────────────────────────────────────
# Data files only — no embedded Bash scripts.
# Complex scripts belong in the Packer image (/usr/local/bin/).
write_files:

# Optional: place provided files (assignment_files)
%{ for slot_key, file in assignment_files ~}
  - path: '/tmp/assignment/${file.name}'
    permissions: '0644'
    owner: 'root:root'
    encoding: b64
    content: '${file.content_b64}'
%{ endfor ~}

# One .env file per user with credentials
# Important: owner 'root:<service-user>' + permissions '0640'
# so the running service can read the file (not root:root 0600)
%{ for user in team_users ~}
  - path: '/etc/myapp/users/${replace(replace(user.email, "@", "_at_"), ".", "-")}.env'
    permissions: '0640'
    owner: 'root:myapp'
    content: |
      EMAIL=${user.email}
      USERNAME=${user.username}
      PASSWORD=${user.password}
%{ endfor ~}

# ── runcmd: run the provisioning script ───────────────────────────────────────
# Single entry only — colons outside strings break YAML parsing.
# The script must be present in the Packer image under /usr/local/bin/.
runcmd:
  - bash /usr/local/bin/myapp-provision.sh > /var/log/myapp-provision.log 2>&1
