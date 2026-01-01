# template-app: OpenStack + Packer (Image-Build) + Terraform (Infra-Deployment)

## Ziel
Eine Lösung für reproduzierbare Images, saubere Trennung von Images und Infrastruktur, sowie ein solider Startpunkt für eigene Anwendungen.

---

## Ordnerstruktur

```plaintext
template-app/
├── packer/
│   ├── template.pkr.hcl   # Packer Template
│   └── scripts/
│       └── provision.sh   # Provisioning (läuft beim Image-Build)
│
├── terraform/
│   ├── main.tf            # OpenStack Ressourcen
│   ├── variables.tf       # Terraform Variablen
│   ├── outputs.tf         # Outputs (z. B. Floating IP)
│   ├── terraform.tfvars   # Eigene Werte (lokal, nicht committen)
│   └── .terraform/
│
└── .gitignore
└── README.md
```

---

## Voraussetzungen (lokal)

**Software-Abhängigkeiten:**
- **Packer**: Version >= 1.9
- **Terraform**: Version >= 1.5
- **OpenStack CLI** (optional, empfohlen)

**Für macOS (Homebrew):**

```bash
brew install packer terraform openstackclient
```

---

## OpenStack Login – `clouds.yaml` (nicht committen)

**Authentifizierungsdatei `clouds.yaml` (lokal):**
Standardpfad:

```plaintext
~/.config/openstack/clouds.yaml
```

Beispielkonfiguration:

```yaml
clouds:
  openstack:
    auth:
      auth_url: <AUTH_URL>
      username: "<USERNAME>"
      password: "<PASSWORD>"
      project_id: <PROJECT_ID>
      project_name: "<PROJECT_NAME>"
      user_domain_name: "<USER_DOMAIN_NAME>"
    region_name: "<REGION_NAME>"
    interface: "<INTERFACE>"
    identity_api_version: <IDENTITY_API_VERSION>
```

Rechte setzen:

```bash
chmod 600 ~/.config/openstack/clouds.yaml
```

Teste die Authentifizierung:

```bash
export OS_CLOUD=openstack
openstack token issue
```

---

## Packer – Image erstellen

Gehe in das Packer-Verzeichnis und führe die Befehle aus:

```bash
cd packer
packer init .
# Optional: packer init -upgrade .
packer validate .
export OS_CLOUD=openstack
packer build .
```

**Ergebnis:**
- Neues Image in OpenStack Glance
- Image-Name wird als Output angezeigt und später in Terraform verwendet

---

## Provisioning – `packer/scripts/provision.sh`

**Provisioning-Skript:**
Definiere, was im Image enthalten sein soll:
- Pakete installieren
- Services konfigurieren
- Webserver / App
- Ports festlegen

**Änderungen** hier erfordern immer einen neuen Image-Build:

```bash
packer build .
```

---

## Terraform – Deployment

Im `terraform`-Verzeichnis:

```bash
cd terraform
# terraform.tfvars lokal anlegen/anpassen (nicht committen)
terraform init
terraform plan
terraform apply
```

**Nach dem Terraform Apply:**
- Floating IP als Output
- App ist über den Browser erreichbar

---

## Was erfordert welche Aktion?

| Änderung           | Aktion         |
|--------------------|------------------|
| `provision.sh`    | `packer build .` |
| Packer Template   | `packer build .` |
| Terraform Dateien | `terraform apply` |
| App-Code im Image | `packer build .` |

---

## Aufräumen

**Infrastruktur entfernen:**

```bash
terraform destroy
```

**Image entfernen:**

```bash
openstack image list
openstack image delete <IMAGE_ID>
```

---

## Typischer Workflow

1. Packer nutzen:

```bash
cd packer
packer init .
packer build .
```

2. Terraform-Deployment:

```bash
cd ../terraform
terraform init
terraform apply
```

---

## Hinweise
- `clouds.yaml` niemals committen
- `terraform.tfvars` ist lokal/projektspezifisch
- Security Groups müssen den App-Port erlauben
- Packer hat keinen State, Terraform schon