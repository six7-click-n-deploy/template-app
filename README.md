# OpenStack App Template mit Contract-System

Dieses Repository ist ein **App-Template** für den Appstore mit automatischer User-Verwaltung.

**Funktionen:**
- **Packer**: Baut VM-Images mit installierter App
- **Terraform**: Deployt Infrastruktur + erstellt automatisch User-Accounts
- **CONTRACT-System**: Klare Trennung zwischen Platform-Team und App-Entwickler

---

## 🏗️ Contract-System

### Konzept

Der Worker/Platform-Team setzt **alle Variablen per `-var` Flags**. Es gibt **keine .tfvars/.pkrvars Files**!

```
┌─────────────────────────────────────┐
│  Platform-Team / Worker             │
│  ================================    │
│  Setzt zur Laufzeit:                │
│  • OpenStack Account-Werte          │
│  • Network UUIDs                    │
│  • Teams mit User-Emails            │
└─────────────────────────────────────┘
            ↓ (via -var flags)
┌─────────────────────────────────────┐
│  Template (dieser Repo)             │
│  ================================    │
│  • Deklariert CONTRACT-Variablen    │
│  • Definiert Defaults               │
│  • Implementiert User-Management    │
└─────────────────────────────────────┘
            ↓
┌─────────────────────────────────────┐
│  App-Entwickler                     │
│  ================================    │
│  Kann anpassen:                     │
│  • provision.sh (App-Installation)  │
│  • Security Group Rules             │
│  • User-Account Logik               │
└─────────────────────────────────────┘
```

### CONTRACT-Variablen

**Packer (PFLICHT):**
- `app_name` - App Name für Image
- `app_version` - Version für Image
- `networks` - OpenStack Netzwerk-UUIDs für Build-VM
- `security_groups` - Security Groups für Build-VM
- `floating_ip_pool` - External Network für Floating IP

**Terraform (PFLICHT):**
- `image_name` - Name des Packer-Images (Format: `app_name-app_version`)
- `network_uuid` - UUID des internen Netzwerks
- `users` - Teams mit User-Emails (kann leer sein)

**Terraform (OPTIONAL):**
- `key_pair` - SSH Key Pair Name (default: `null`)
- `floating_ip_pool` - External Network (default: `null` für nur-intern)

---

## 📁 Struktur

```plaintext
template-app/
├── packer/
│   ├── template.pkr.hcl        # Packer Build Config (hardcoded Defaults)
│   ├── variables.pkr.hcl       # CONTRACT-Variablen Deklaration
│   └── scripts/
│       └── provision.sh        # App Installation (Node.js Beispiel)
│
├── terraform/
│   ├── main.tf                 # Infrastruktur + User-Management
│   ├── variables.tf            # CONTRACT-Variablen Deklaration
│   ├── outputs.tf              # User-Account Access-Informationen
│   └── user-data.yaml.tpl      # Cloud-init für User-Accounts
│
└── README.md
```

---

## 🚀 Quickstart

### 1. Template verwenden

```bash
# "Use this template" auf GitHub oder klonen
git clone <REPO_URL> my-app
cd my-app
```

### 2. App anpassen (Optional)

**Packer - App Installation:**
```bash
# Bearbeite packer/scripts/provision.sh
# Installiere deine App statt Node.js Beispiel
```

**Terraform - Infrastruktur:**
```bash
# main.tf: Security Group Rules, Instanz-Config anpassen
# user-data.yaml.tpl: User-Account Logik anpassen
```

### 3. Image bauen

```bash
cd packer
packer build \
  -var="app_name=myapp" \
  -var="app_version=1.0.0" \
  -var='networks=["net-uuid-1"]' \
  -var='security_groups=["default"]' \
  -var="floating_ip_pool=public" \
  template.pkr.hcl
```

**Output:** Image mit Name `myapp-1.0.0`

### 4. Infrastruktur deployen

```bash
cd terraform
terraform init
terraform apply \
  -var="image_name=myapp-1.0.0" \
  -var="network_uuid=net-abc-123" \
  -var='users={"developers":[{"email":"john@example.com"}],"admins":[{"email":"admin@example.com"}]}'
```

**Output:**
```json
user_accounts = {
  "developers-john" = {
    type     = "password"
    ip       = "1.2.3.4"
    port     = 22
    username = "john"
    auth     = "Xf8k2Lp9Qr3T"
  }
  "admins-admin" = {
    type     = "password"
    ip       = "1.2.3.4"
    port     = 22
    username = "admin"
    auth     = "Yw5n7Mp1Vt6S"
  }
}
```

### 5. User-Zugang testen

```bash
ssh john@1.2.3.4
# Passwort: Xf8k2Lp9Qr3T (aus Output)
```

---

## 📋 Variablen-Referenz

### Packer CONTRACT-Variablen

| Variable | Typ | Pflicht | Beschreibung |
|----------|-----|---------|--------------|
| `app_name` | string | ✅ | App Name für Image (wird zu: `app_name-app_version`) |
| `app_version` | string | ✅ | App Version |
| `networks` | list(string) | ✅ | OpenStack Netzwerk-UUIDs für Build-VM |
| `security_groups` | list(string) | ✅ | Security Groups für Build-VM |
| `floating_ip_pool` | string | ✅ | External Network Name für Floating IP |

**Hardcoded Defaults in `template.pkr.hcl`:**
- `source_image_name` = "Ubuntu 22.04"
- `flavor` = "gp1.small"
- `ssh_username` = "ubuntu"

### Terraform CONTRACT-Variablen

| Variable | Typ | Pflicht | Default | Beschreibung |
|----------|-----|---------|---------|--------------|
| `image_name` | string | ✅ | - | Name des Packer-Images |
| `network_uuid` | string | ✅ | - | UUID des internen Netzwerks |
| `users` | map(list(object)) | ❌ | `{}` | Teams mit User-Emails |
| `key_pair` | string | ❌ | `null` | SSH Key Pair Name |
| `floating_ip_pool` | string | ❌ | `null` | External Network (null = nur-intern) |

**Hardcoded in `main.tf`:**
- `flavor` = "gp1.small"
- `instance_name` = "app-instance"
- Security Groups: SSH (22), HTTP (80), HTTPS (443)

---

## 👥 User-Management

### Wie funktioniert es?

1. **Input:** Platform-Team gibt `users` Variable mit Teams und Emails
2. **Processing:** Terraform erstellt flache User-Map
3. **Creation:** Cloud-init erstellt Linux-Accounts mit Passwörtern
4. **Output:** `user_accounts` mit Zugangs-Informationen

### User-Struktur

```hcl
users = {
  "team1" = [
    { email = "john@example.com" },
    { email = "jane@example.com" }
  ]
  "team2" = [
    { email = "bob@example.com" }
  ]
}
```

**Wird zu Linux-Accounts:**
- Username: Email-Prefix (z.B. `john` aus `john@example.com`)
- Gruppe: Team-Name (z.B. `team1`)
- Passwort: 16 Zeichen, auto-generiert
- Sudo: Ja, ohne Passwort

### Output CONTRACT-Schema

```hcl
user_accounts = {
  "<team>-<username>" = {
    type     = "password" | "ssh" | "api-token"
    ip       = "1.2.3.4"
    port     = 22 | 80 | 3306
    username = "john-doe"
    auth     = "password-string" | "ssh-key" | "token"
  }
}
```

---

## 🔧 Anpassungen

### App Installation ändern

Bearbeite [packer/scripts/provision.sh](packer/scripts/provision.sh):

```bash
#!/bin/bash
set -e

# System Update
apt-get update
apt-get upgrade -y

# HIER: Installiere deine App
# Beispiel Python:
apt-get install -y python3 python3-pip
pip3 install flask

# Beispiel Java:
apt-get install -y openjdk-17-jre
# Deploy JAR...

# Systemd Service erstellen
cat > /etc/systemd/system/app.service <<EOF
[Unit]
Description=My App

[Service]
ExecStart=/usr/bin/python3 /opt/app/main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable app.service
```

### Security Group Rules anpassen

In [terraform/main.tf](terraform/main.tf):

```hcl
# Neue Ports hinzufügen
resource "openstack_networking_secgroup_rule_v2" "custom_port" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.app_sg.id
}
```

### User-Account Logik ändern

In [terraform/user-data.yaml.tpl](terraform/user-data.yaml.tpl):

```yaml
# Beispiel: Nur bestimmte Teams sudo-Rechte
users:
%{ for user_id, user in users ~}
  - name: ${user.username}
    groups: ${user.team}
    shell: /bin/bash
    %{ if user.team == "admins" ~}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    %{ endif ~}
%{ endfor ~}
```

---

## 🔐 Security Best Practices

1. **Passwörter:** Automatisch generiert (16 Zeichen, Sonderzeichen)
2. **SSH:** Passwort-Auth aktiviert (kann auf SSH-Keys umgestellt werden)
3. **Sudo:** Nur für vertrauenswürdige User aktivieren
4. **Security Groups:** Nur benötigte Ports öffnen
5. **Floating IP:** Nur wenn extern nötig (sonst `floating_ip_pool = null`)

---

## 🐛 Troubleshooting

### Packer Build fehlschlägt

```bash
# Check: Hast du Zugriff auf OpenStack?
openstack server list

# Check: Sind Netzwerke/Security Groups korrekt?
openstack network show <UUID>
openstack security group show <NAME>
```

### Terraform Apply fehlschlägt

```bash
# Check: Existiert das Packer-Image?
openstack image show myapp-1.0.0

# Check: Netzwerk UUID korrekt?
openstack network show <UUID>

# Detaillierte Logs
terraform apply -var="..." TF_LOG=DEBUG
```

### User kann sich nicht einloggen

```bash
# Check: SSH Passwort-Auth aktiviert?
ssh -v john@1.2.3.4

# Check: Cloud-init Logs auf VM
ssh ubuntu@<ip> -i <key>
sudo cat /var/log/cloud-init-output.log
```

---

## 📚 Weitere Ressourcen

- [Packer OpenStack Builder](https://developer.hashicorp.com/packer/plugins/builders/openstack)
- [Terraform OpenStack Provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)

---

## 📝 License

Siehe [LICENSE](LICENSE) Datei.

# Floating IP Pool
floating_ip_pool = "DHBW"

# SSH CIDR (empfohlen: spezifische IP)
ssh_cidr = "123.45.67.89/32"

# USER & ACCESS MANAGEMENT
users = {
  developers = [
    {
      email     = "dev1@example.com"
      username  = "dev1"
      auth_type = "ssh"
    },
    {
      email     = "dev2@example.com"
      username  = "dev2"
      auth_type = "ssh"
    }
  ]
  
  admins = [
    {
      email     = "admin@example.com"
      username  = "admin"
      auth_type = "ssh"
    }
  ]
  
  testers = [
    {
      email     = "tester@example.com"
      username  = "tester"
      auth_type = "password"
    }
  ]
}
```

---

## 🎨 CUSTOM-Variablen (App-Entwickler)

### Packer Custom (`packer/custom.pkrvars.hcl`)

Frei definierbare App-spezifische Variablen:

```hcl
app_name         = "my-awesome-app"
app_version      = "v2.0"
provision_script = "scripts/provision.sh"
```

### Terraform Custom (`terraform/custom.tfvars`)

```hcl
instance_name = "my-awesome-app"
image_name    = "my-awesome-app-v2.0"
flavor        = "gp1.medium"

# Öffentliche Ports freigeben
allowed_tcp_ports = [80, 443, 8080]

# Floating IP aktivieren
enable_floating_ip = true

# Custom Metadata
metadata = {
  environment = "production"
  team        = "backend"
  cost_center = "CC-1234"
}
```

---

## 👥 User & Access Management

### User-Konfiguration im Contract

Jeder User benötigt:
- `email`: Kontakt-Email
- `username`: System-Username
- `auth_type`: `"ssh"` (Key-based) oder `"password"`

```hcl
users = {
  team_name = [
    {
      email     = "user@example.com"
      username  = "username"
      auth_type = "ssh"  # oder "password"
    }
  ]
}
```

### Access-Informationen abrufen

Nach `terraform apply` stehen folgende Outputs zur Verfügung:

**1. Vollständige Access-Infos (sensitive):**
```bash
terraform output -json user_access | jq
```

Output-Struktur pro User:
```json
{
  "team-username": {
    "team": "team_name",
    "email": "user@example.com",
    "username": "username",
    "access": {
      "type": "ssh",
      "ip": "1.2.3.4",
      "port": 22,
      "auth": {
        "private_key_path": "terraform/.ssh-keys/username",
        "public_key_path": "terraform/.ssh-keys/username.pub"
      }
    },
    "connection_string": "ssh -i .ssh-keys/username username@1.2.3.4"
  }
}
```

**2. Übersicht ohne sensitive Daten:**
```bash
terraform output user_access_summary
```

**3. Fertige SSH-Befehle:**
```bash
terraform output ssh_connection_commands
```

### SSH-Zugriff verwenden

**Für SSH-basierte User:**
```bash
# Private Key wurde generiert in: terraform/.ssh-keys/username
ssh -i terraform/.ssh-keys/username username@IP_ADDRESS
```

**Für Password-basierte User:**
```bash
# Passwort aus sensitive Output holen
terraform output -json user_access | jq '.["team-username"].access.auth.password'

# SSH mit Passwort
ssh username@IP_ADDRESS
```

---

## 🔐 Sicherheit & Best Practices

### Was NICHT committen:

```plaintext
❌ contract.pkrvars.hcl      # OpenStack Credentials
❌ custom.pkrvars.hcl         # Könnte secrets enthalten
❌ contract.tfvars            # User-Daten, Network-IDs
❌ custom.tfvars              # Könnte secrets enthalten
❌ .ssh-keys/                 # Generierte SSH Keys
❌ terraform.tfstate          # State mit sensitive Daten
```

✅ Die `.gitignore` ist bereits konfiguriert!

### Empfohlene Sicherheitsmaßnahmen:

1. **SSH CIDR einschränken:**
   ```hcl
   ssh_cidr = "123.45.67.89/32"  # Nur deine IP
   ```

2. **Minimale Ports öffnen:**
   ```hcl
   allowed_tcp_ports = [443]  # Nur HTTPS
   ```

3. **SSH-Keys bevorzugen:**
   ```hcl
   auth_type = "ssh"  # Sicherer als Passwörter
   ```

4. **Secrets aus Image fernhalten:**
   - Nutze Cloud-Init / User Data
   - Nutze HashiCorp Vault
   - Nutze Environment Variables

---

## 🔄 Workflow-Beispiele

### Image neu bauen (z.B. nach App-Update)

```bash
cd packer

# Optional: Version erhöhen in custom.pkrvars.hcl
# app_version = "v2.1"

packer build -var-file=contract.pkrvars.hcl -var-file=custom.pkrvars.hcl .
```

### Infrastruktur aktualisieren

```bash
cd terraform

# Neues Image verwenden in custom.tfvars
# image_name = "my-app-v2.1"

terraform apply -var-file=contract.tfvars -var-file=custom.tfvars
```

### User hinzufügen

```bash
# contract.tfvars bearbeiten:
users = {
  developers = [
    # ... existing users ...
    {
      email     = "newdev@example.com"
      username  = "newdev"
      auth_type = "ssh"
    }
  ]
}

# Apply
terraform apply -var-file=contract.tfvars -var-file=custom.tfvars

# Neuen User's SSH Command holen
terraform output ssh_connection_commands
```



---

## 🧹 Cleanup

### Infrastruktur entfernen
```bash
cd terraform
terraform destroy -var-file=contract.tfvars -var-file=custom.tfvars
```

### Image löschen
```bash
openstack image delete my-app-v1
```

### SSH Keys entfernen
```bash
rm -rf terraform/.ssh-keys/
```

---

## 🛠️ Troubleshooting

### Packer: SSH Timeout während Build

**Problem:** Build-VM nicht erreichbar

**Lösung:**
- Security Groups müssen SSH erlauben
- Netzwerk-Konfiguration prüfen
- Optional: `use_floating_ip = true` in Packer

### Terraform: "network_uuid" nicht gefunden

**Problem:** Falsche Netzwerk-UUID

**Lösung:**
```bash
openstack network list
# Kopiere die UUID des INTERNEN Netzwerks (nicht external!)
```

### User kann sich nicht per SSH anmelden

**Problem:** Key nicht korrekt übertragen

**Lösung:**
1. Prüfe ob Key existiert: `ls -la terraform/.ssh-keys/`
2. Prüfe Permissions: `chmod 600 terraform/.ssh-keys/username`
3. Cloud-Init Logs auf VM prüfen: `sudo cat /var/log/cloud-init.log`

### Terraform: Validation Error "auth_type"

**Problem:** Ungültiger auth_type Wert

**Lösung:** Nur `"ssh"` oder `"password"` erlaubt:
```hcl
auth_type = "ssh"  # ✅ Richtig
auth_type = "SSH"  # ❌ Falsch (Case-sensitive!)
```

---

## 📚 Voraussetzungen & Setup

### Tools installieren

- **Packer** >= 1.9
- **Terraform** >= 1.5
- **OpenStack CLI** (optional, für Debug)

**macOS:**
```bash
brew install packer terraform python-openstackclient
```

### OpenStack Authentication

**`clouds.yaml` erstellen:**

Standardpfad: `~/.config/openstack/clouds.yaml`

```yaml
clouds:
  openstack:
    auth:
      auth_url: <AUTH_URL>
      username: "<USERNAME>"
      password: "<PASSWORD>"
      project_name: "<PROJECT_NAME>"
      user_domain_name: "<USER_DOMAIN_NAME>"
    region_name: "<REGION_NAME>"
    interface: "public"
    identity_api_version: 3
```

```bash
chmod 600 ~/.config/openstack/clouds.yaml
export OS_CLOUD=openstack
openstack token issue  # Test
```

---

## 🎯 Zusammenfassung: Was macht wer?

| Rolle | Aufgabe | Files |
|-------|---------|-------|
| **Platform-Team** | Stellt Contract-Files bereit mit OpenStack-Config & User-Management | `contract.pkrvars.hcl`<br>`contract.tfvars` |
| **App-Entwickler** | Konfiguriert App-spezifische Werte & Provisioning | `custom.pkrvars.hcl`<br>`custom.tfvars`<br>`provision.sh` |
| **Template** | Generiert automatisch User-Accounts & Access-Infos | `users.tf`<br>`outputs.tf` |

### Output-Struktur für jeden User:

```json
{
  "type": "ssh" oder "password",
  "ip": "1.2.3.4",
  "port": 22,
  "username": "username",
  "auth": {
    // SSH: private_key_path & public_key_path
    // Password: password
  }
}
```

---

## 📝 Weitere Ressourcen

- **OpenStack Docs:** https://docs.openstack.org/
- **Packer Docs:** https://www.packer.io/docs
- **Terraform OpenStack Provider:** https://registry.terraform.io/providers/terraform-provider-openstack/openstack

---

## 📝 Lizenz

Siehe [LICENSE](LICENSE) Datei.