# OpenStack Template: Packer (Image) + Terraform (Deployment)

Dieses Repository ist ein **Template** für OpenStack-Projekte mit sauberer Trennung von:
- **Packer**: baut ein wiederverwendbares **Image**
- **Terraform**: deployt **Infrastruktur** (VM, Security Group, optional Floating IP)

Es enthält **keine App**. Du füllst nur die Stellen aus, an denen du deine eigene Anwendung/Runtime ins Image bringst.

---

## Struktur

```plaintext
template-app/
├── packer/
│   ├── template.pkr.hcl          # Packer Template (Image Build)
│   ├── variables.pkr.hcl         # Packer-Variablen mit @openstack:-Annotationen
│   └── scripts/
│       └── provision.sh          # Provisioning Script (DEIN Inhalt)
│
├── terraform/
│   ├── main.tf                   # OpenStack Ressourcen (VMs, Ports, Floating IPs)
│   ├── variables.tf              # Variablen mit [BACKEND]/[CONTRACT]-Annotationen
│   ├── outputs.tf                # Outputs (user_accounts, team_vms, teams_summary)
│   ├── user-data.yaml.tpl        # cloud-init Template (User-Credentials, runcmd)
│   └── terraform.tfvars          # Lokale Konfiguration (nicht committen)
│
├── .github/
│   ├── workflows/
│   │   ├── packer.yml            # CI: packer fmt + validate
│   │   └── terraform.yml         # CI: terraform fmt + validate + tflint + tfsec
│   └── actions/
│       └── action.yml            # Custom Action: Packer installieren
├── .gitignore
└── README.md
```

---

## Voraussetzungen

- **Packer** >= 1.9
- **Terraform** >= 1.5
- **OpenStack Zugang** (clouds.yaml oder OS_* env vars)
- Optional: **OpenStack CLI** (für Debug/Listen/Löschen)

### macOS (Homebrew)

```bash
brew install packer terraform python-openstackclient
```

---

## OpenStack Auth (lokal, nicht committen)

**Empfohlen: `clouds.yaml`**

Die `clouds.yaml` kann direkt aus OpenStack heruntergeladen werden:
**Profil (oben rechts) → OpenStack clouds.yaml-Datei herunterladen**

> **Wichtig:** Die heruntergeladene Datei enthält kein Passwort. Die folgende Zeile muss manuell unter `auth:` ergänzt werden:
> ```yaml
>       password: "<DEIN PASSWORT>"
> ```

Die clouds.yaml-Datei muss dem Standardpfad eingefügt werden:
```plaintext
~/.config/openstack/clouds.yaml
```

Beispiel:
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

Rechte setzen:
```bash
chmod 600 ~/.config/openstack/clouds.yaml
```

Cloud auswählen:
```bash
export OS_CLOUD=openstack
```

Test:
```bash
openstack token issue
```

---

## Schritt 1: Repo als Template nutzen

Auf GitHub das Template-Repository öffnen: **[six7-click-n-deploy/template-app](https://github.com/six7-click-n-deploy/template-app)**

Oben rechts auf **"Use this template"** → **"Create a new repository"** klicken.

> **Wichtig bei privaten Repositories:** Den Collaborator **`six7clickndeploy`** zum Repository hinzufügen, damit der AppStore Zugriff hat:
> **Settings → Collaborators → Add people → `six7clickndeploy`**
>
> Bei öffentlichen Repositories ist dieser Schritt nicht notwendig.

Anschließend das neue Repository lokal klonen und bearbeiten:
```bash
git clone <DEINE_REPO_URL>
cd <REPO_NAME>
```

---

## Schritt 2: Packer konfigurieren (Image Build)

### 2.1 Variablen konfigurieren (`variables.pkr.hcl`)

Die Packer-Variablen werden in `packer/variables.pkr.hcl` definiert. Diese Variablen werden vom AppStore beim Deployment angezeigt — der Nutzer trifft dort eine Auswahl. Damit das UI die Variablen korrekt darstellt, müssen sie einer festen Beschreibungs-Konvention folgen.

**Pflicht-Variablen für jedes Packer-Image:**

```hcl
variable "image_name" {
  type        = string
  description = "@openstack:image:name"
  default     = "my-app-vX"
}

variable "networks" {
  type        = list(string)
  description = "@openstack:network:id:list"
  default     = ["4971e080-966d-485e-a161-3e2b7fefad53"]
}

variable "security_groups" {
  type        = list(string)
  description = "@openstack:security_group:id:list"
  default     = ["<SECURITY-GROUP-ID>"]
}
```

**Beschreibungs-Konvention:**

Die `description` muss folgendem Format folgen, damit der AppStore die Variable korrekt im UI anzeigt:

```
@openstack:<type>:<mode>:<multi>
```

| Platzhalter | Mögliche Werte |
|-------------|----------------|
| `type` | `network`, `subnet`, `flavor`, `image`, `keypair`, `security_group`, `floating_ip_pool`, `volume`, `router`, `availability_zone` |
| `mode` | `id` oder `name` |
| `multi` | `list` oder `single` |

Je nach Annotation rendert der AppStore die passende Auswahl-Komponente (z.B. Dropdown für `name`, Multi-Select für `list`). Im Feld `default` können Standardwerte hinterlegt werden.

Der Wert im `default`-Feld wird im AppStore als Standardwert vorausgefüllt angezeigt.


### 2.2 Provisioning anpassen (DEIN Inhalt)

**Datei:** `packer/scripts/provision.sh`

Hier definierst du, was ins Image kommt:
- Pakete/Runtime installieren
- App-Artefakte deployen (z.B. Binary, Container, Webapp)
- Konfiguration
- systemd Services
- (optional) Reverse Proxy / TLS

**Wichtig:**
- keine Secrets hardcoden
- idempotent schreiben (mehrfaches Ausführen sollte nicht kaputt machen)

---

## Schritt 3: Image bauen

Im `packer/` Ordner:
```bash
packer init .
packer validate .
packer build .
```

**Ergebnis:**
- Neues Image erscheint in OpenStack (Glance)
- Image-Name entspricht `image_name` (wird später in Terraform verwendet)

---

## Schritt 4: Terraform konfigurieren

### 4.1 Variablen (`variables.tf`)

Die Terraform-Variablen folgen derselben `@openstack:`-Konvention wie bei Packer. **Pflicht-Variablen** für jede App:

**Beschreibungs-Konvention:**

```
@openstack:<type>:<mode>
```

| Platzhalter | Mögliche Werte |
|-------------|----------------|
| `type` | `network`, `subnet`, `flavor`, `image`, `keypair`, `security_group`, `floating_ip_pool`, `volume`, `router`, `availability_zone` |
| `mode` | `id` oder `name` |

Zusätzlich können Variablen mit `[BACKEND]` oder `[CONTRACT]` als Präfix in der `description` markiert werden:
- `[BACKEND]` — wird vom AppStore/Platform-Admin gesetzt
- `[CONTRACT]` — wird vom Deployer (z.B. Dozent) im AppStore gesetzt

```hcl
variable "image_name" {
  description = "[BACKEND] Name des Packer-Images @openstack:image:name"
  type        = string
  default     = "my-app-vX"
}

variable "network_uuid" {
  description = "[BACKEND] UUID des internen Netzwerks @openstack:network:id"
  type        = string
  default     = "34a00b87-57ce-42c4-8e1b-9ea8a657ec2e"
}

variable "floating_ip_pool" {
  description = "[BACKEND] Name des External Networks für Floating IPs @openstack:floating_ip_pool:name"
  type        = string
  default     = "DHBW"
}

variable "shared_secgroup_id" {
  description = "[BACKEND] ID der gemeinsamen Security Group @openstack:security_group:id"
  type        = string
  default     = "4ffaf007-df66-4250-9118-1bd99378d34a"
}
```

**Optionale Variablen:**

```hcl
# Bei Apps mit User Management:
variable "users" {
  description = "[CONTRACT] Teams mit User-Emails"
  type = map(list(object({
    email = string
  })))
  default = {}
}

# Bei Apps mit Datei-Übergabe:
variable "assignment_files" {
  description = "[CONTRACT] Hochgeladene Begleitmaterialien @openstack:file:all"
  type = map(object({
    name         = string
    content_b64  = string
    size         = number
    content_type = string
  }))
  default = {}
}
```

Der Wert im `default`-Feld wird im AppStore als Standardwert vorausgefüllt angezeigt.

---

### 4.2 Outputs (`outputs.tf`)

Die Datei `outputs.tf` definiert was nach dem Deployment ausgegeben wird — der AppStore liest diese Werte aus und zeigt sie dem Nutzer an.

**Bei Apps mit User Management sind folgende Outputs Pflicht:**

```hcl
# CONTRACT-SCHEMA:
# local.user_accounts = {
#   "<team>-<username>": {
#     type     = "password"
#     ip       = "1.2.3.4"
#     port     = 80
#     username = "alice@example.com"
#     auth     = "<passwort>"
#   }
# }

output "user_accounts" {
  description = "[CONTRACT] User accounts mit Zugangsdaten"
  value       = local.user_accounts
  sensitive   = true
}

output "team_vms" {
  description = "Details aller Team-VMs"
  value = {
    for team in local.teams_list : team => {
      instance_id   = openstack_compute_instance_v2.team_vm[team].id
      instance_name = openstack_compute_instance_v2.team_vm[team].name
      fixed_ip      = openstack_networking_port_v2.team_port[team].all_fixed_ips[0]
      floating_ip   = local.enable_floating_ip ? openstack_networking_floatingip_v2.team_fip[team].address : null
      url           = "http://${...}"
    }
  }
}
```

Die Feldnamen in `user_accounts` (`type`, `ip`, `port`, `username`, `auth`) und der Output-Name `team_vms` sind **fix** — der AppStore erwartet exakt diese Struktur.

**Empfohlen zusätzlich:**

```hcl
output "teams_summary" {
  description = "Übersicht: Teams und User-Anzahl"
  value = {
    for team in local.teams_list : team => length([...])
  }
}
```

---

### 4.3 Lokale Konfiguration (`terraform.tfvars`)

Für lokales Testen wird eine `terraform.tfvars` angelegt (nicht committen — steht in `.gitignore`):

```hcl
# Pflicht
image_name         = "my-app-v1"
network_uuid       = "34a00b87-57ce-42c4-8e1b-9ea8a657ec2e"
floating_ip_pool   = "DHBW"
shared_secgroup_id = "4ffaf007-df66-4250-9118-1bd99378d34a"

# Optional: User Management
users = {
  "Team-1" = [
    { email = "alice@example.com" },
    { email = "bob@example.com" }
  ]
}
```

Nach `terraform apply` enthält die `terraform.tfstate` alle Outputs sowie Details zu den erstellten Ressourcen (IPs, IDs, Zugangsdaten).

---

### 4.4 User Management (`user-data.yaml.tpl`)

Die Datei `user-data.yaml.tpl` ist ein cloud-init-Template das beim VM-Boot ausgeführt wird. Sie übergibt Laufzeit-Daten (User-Credentials, Dateien) an die VM.

**Struktur und worauf App-Entwickler achten müssen:**

```yaml
#cloud-config

bootcmd:
  # Wird sehr früh ausgeführt — vor write_files
  # Verzeichnisse anlegen die write_files benötigt
  - mkdir -p /etc/myapp/users
  - chown root:root /etc/myapp/users
  - chmod 750 /etc/myapp/users

write_files:
  # Pro User eine .env-Datei mit Zugangsdaten
  # Terraform-Template-Syntax: %{ for ... ~} ... %{ endfor ~}
# %{ for user in team_users ~}
  - path: '/etc/myapp/users/...'
    permissions: '0640'
    owner: 'root:root'
    content: |
      EMAIL=...
      PASSWORD=...
# %{ endfor ~}

runcmd:
  # Das Provision-Script ausführen — muss im Packer-Image vorhanden sein
  - bash /usr/local/bin/myapp-provision.sh > /var/log/myapp-provision.log 2>&1
```

**Wichtige Regeln:**

- `bootcmd` läuft **vor** `write_files` — Verzeichnisse die von `write_files` beschrieben werden, müssen hier angelegt werden
- Dateiberechtigungen für Service-User: `owner: 'root:<service-user>'` + `permissions: '0640'` — nicht `root:root 0600`, sonst kann der laufende Dienst die Datei nicht lesen
- **Kein eingebettetes Bash-Script** in `write_files` — komplexe Scripts gehören ins Packer-Image, nicht ins YAML
- `runcmd` darf **keine Doppelpunkte außerhalb von Strings** enthalten — diese brechen das YAML-Parsing und cloud-init führt gar nichts aus
- Terraform-Template-Variablen (`${variable}`, `%{ for ... }`) werden zur Plan-Zeit ersetzt; `%%` schreibt ein literales `%`

Eine beispielhafte Implementierung mit allen drei Abschnitten (`bootcmd`, `write_files`, `runcmd`) ist in der Template-App unter `terraform/user-data.yaml.tpl` hinterlegt.

---


## Schritt 5: Infrastruktur deployen

```bash
terraform init
terraform validate
```

Vor dem eigentlichen Deployment empfiehlt sich ein `terraform plan` um eine Vorschau zu erhalten:

```bash
terraform plan
```

Die Ausgabe zeigt u.a.:
- Wie viele VMs mit der aktuellen Konfiguration deployed werden (z.B. `2 to add` bei zwei Teams)
- Welche Ressourcen erstellt, geändert oder gelöscht werden (Ports, Floating IPs, Passwörter)
- Eine Zusammenfassung am Ende: `Plan: X to add, Y to change, Z to destroy`

Erst danach das Deployment starten:

```bash
terraform apply
```

**Nach apply erhältst du folgende Outputs:**
- `user_accounts` — Zugangsdaten aller User (sensitiv, nicht direkt angezeigt — mit `terraform output -json user_accounts` abrufbar)
- `team_vms` — Details aller Team-VMs mit IP-Adressen und App-URL
- `teams_summary` — Übersicht der Teams mit jeweiliger User-Anzahl

---

## Was muss ich wann tun?

| Änderung | Was tun? |
|----------|----------|
| `packer/scripts/provision.sh` | `packer build ...` |
| `packer/template.pkr.hcl` | `packer build ...` |
| Terraform .tf Dateien | `terraform apply` |
| Ports (Security Group) | `terraform apply` |
| Neues Image verwenden | `packer build ...` + `terraform apply` |

---

## Cleanup

### Infrastruktur entfernen
```bash
cd terraform
terraform destroy
```

### Image entfernen (optional)
```bash
openstack image list
openstack image delete <IMAGE_ID>
```

---

## GitHub Actions CI/CD

Beim Pushen in das Repository durchläuft der Code automatisch einen GitHub Actions Workflow. Damit dieser erfolgreich ist, sollten die folgenden Checks **lokal vorab** ausgeführt werden.

**Voraussetzungen (einmalig installieren):**
```bash
# tflint
brew install tflint          # macOS
# oder: https://github.com/terraform-linters/tflint#installation

# tfsec
brew install tfsec           # macOS
# oder: https://github.com/aquasecurity/tfsec#installation
```

**Terraform:**
```bash
cd terraform
terraform fmt          # Formatierung korrigieren
terraform validate     # Syntax prüfen
terraform plan         # Deployment-Vorschau
tflint --recursive     # Linter
tfsec .                # Security-Check
```

**Packer:**
```bash
cd packer
packer fmt .           # Formatierung korrigieren
packer validate .      # Syntax prüfen
```

Schlägt einer dieser Checks fehl, wird der Workflow als fehlgeschlagen markiert.

---

## Troubleshooting (kurz)

### Packer kommt nicht per SSH auf die Build-VM
- `security_groups` in Packer müssen SSH erlauben (von deinem Runner/Bastion)
- Wenn Build-VM nur intern erreichbar: Runner muss im selben Netz sein oder
- `use_floating_ip=true` + `floating_ip_pool` setzen

### VM ist deployed, aber Service nicht erreichbar
- `allowed_tcp_ports` in Terraform setzen (z.B. [80] oder [443])
- Service im Image läuft wirklich? (systemd status, logs, etc.)
- ggf. `enable_floating_ip=false` → dann nur intern erreichbar (private IP)

---

## Minimaler Quickstart

```bash
# 1) Auth
export OS_CLOUD=openstack

# 2) Image bauen
cd packer
packer init .
packer fmt .
packer validate .
packer build .

# 3) Deploy
cd ../terraform
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

---

## Best Practices

### Sicherheit
- **Secrets niemals hardcoden**: Nutze Umgebungsvariablen, Vault oder Cloud-Init
- **SSH-Zugriff beschränken**: Setze `ssh_cidr` auf deine spezifische IP statt `0.0.0.0/0`
- **Security Groups minimalistisch**: Nur benötigte Ports öffnen

### Entwicklung
- **Idempotenz**: `provision.sh` muss mehrfach ausführbar sein
- **Versionierung**: Nutze semantische Versionierung für Image-Namen
- **Testing**: Teste Image-Builds in separater Umgebung

### Operations
- **Monitoring**: Implementiere Health-Checks in deiner App
- **Logs**: Nutze structured logging (JSON) für bessere Auswertung
- **Backups**: Plane Backup-Strategien für persistente Daten

---

## Schritt 6: App dem AppStore hinzufügen

Sobald das Repository fertig entwickelt und auf GitHub gepusht ist, kann die App im AppStore registriert werden.

Dafür wird lediglich die **GitHub-URL des Repositories** benötigt, z.B.:

```
https://github.com/<dein-username>/<repo-name>
```

Diese URL im AppStore unter **"App hinzufügen"** eintragen — der AppStore liest daraufhin die Konfiguration (Variablen, Packer-Template, Terraform) automatisch aus dem Repository ein.