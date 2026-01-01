# template-app — OpenStack + Packer (Image-Build) + Terraform (Infra-Deployment)
# Ziel: reproduzierbare Images, Trennung Image/Infra, Startpunkt für eigene Apps

set -euo pipefail

# ------------------------------------------------------------------------------
# Ordnerstruktur
# ------------------------------------------------------------------------------
cat <<'TXT'
template-app/
├── packer/
│   ├── template.pkr.hcl        # Packer Template
│   └── scripts/
│       └── provision.sh        # Provisioning (läuft beim Image-Build)
│
├── terraform/
│   ├── main.tf                 # OpenStack Ressourcen
│   ├── variables.tf            # Terraform Variablen
│   ├── outputs.tf              # Outputs (z. B. Floating IP)
│   ├── terraform.tfvars        # Eigene Werte (lokal, nicht committen)
│   └── .terraform/
│
├── .gitignore
└── README.md
TXT

# ------------------------------------------------------------------------------
# Voraussetzungen (lokal)
# ------------------------------------------------------------------------------
cat <<'TXT'
Voraussetzungen:
- Packer >= 1.9
- Terraform >= 1.5
- (optional, empfohlen) OpenStack CLI

macOS (Homebrew):
  brew install packer terraform openstackclient
TXT

# ------------------------------------------------------------------------------
# OpenStack Login – clouds.yaml (NICHT committen)
# ------------------------------------------------------------------------------
cat <<'TXT'
Authentifizierung via clouds.yaml (lokal, nicht committen)

Standardpfad:
  ~/.config/openstack/clouds.yaml

Beispiel (anpassen):
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

Rechte setzen:
  chmod 600 ~/.config/openstack/clouds.yaml

Test:
  export OS_CLOUD=openstack
  openstack token issue
TXT

# ------------------------------------------------------------------------------
# Packer – Image bauen
# ------------------------------------------------------------------------------
cat <<'TXT'
Packer – Image bauen:
  cd packer
  packer init .
  # optional:
  # packer init -upgrade .
  packer validate .
  export OS_CLOUD=openstack
  packer build .

Ergebnis:
- Neues Image in OpenStack Glance
- Image-Name steht im Output und wird später in Terraform referenziert
TXT

# ------------------------------------------------------------------------------
# Provisioning – packer/scripts/provision.sh
# ------------------------------------------------------------------------------
cat <<'TXT'
Provisioning – packer/scripts/provision.sh:
Hier definierst man, was im Image enthalten ist:
- Pakete installieren
- Services konfigurieren
- Webserver / App
- Ports festlegen

Änderungen hier erfordern immer einen neuen Image-Build:
  packer build .
TXT

# ------------------------------------------------------------------------------
# Terraform – Deployment
# ------------------------------------------------------------------------------
cat <<'TXT'
Terraform – Deployment:
  cd terraform
  # terraform.tfvars lokal anlegen/anpassen (nicht committen)
  terraform init
  terraform plan
  terraform apply

Nach dem Apply:
- z. B. Floating IP als Output
- App ist über den Browser erreichbar
TXT

# ------------------------------------------------------------------------------
# Was erfordert was?
# ------------------------------------------------------------------------------
cat <<'TXT'
Was erfordert was?

Änderung                Aktion
----------------------  ----------------
provision.sh            packer build .
Packer Template         packer build .
Terraform Dateien       terraform apply
App-Code im Image       packer build .
TXT

# ------------------------------------------------------------------------------
# Aufräumen
# ------------------------------------------------------------------------------
cat <<'TXT'
Aufräumen:
Infrastruktur löschen:
  terraform destroy

Image löschen:
  openstack image list
  openstack image delete <IMAGE_ID>
TXT

# ------------------------------------------------------------------------------
# Typischer Workflow
# ------------------------------------------------------------------------------
cat <<'TXT'
Typischer Workflow:
  cd packer
  packer init .
  packer build .

  cd ../terraform
  terraform init
  terraform apply
TXT

# ------------------------------------------------------------------------------
# Hinweise
# ------------------------------------------------------------------------------
cat <<'TXT'
Hinweise:
- clouds.yaml niemals committen
- terraform.tfvars ist lokal/projektspezifisch
- Security Groups müssen den App-Port erlauben
- Packer hat keinen State, Terraform schon
TXT
