# App-Autor-Guide

Dieser Guide ist die einzige Quelle, die ein App-Entwickler lesen muss, um eine
funktionierende Click-n-Deploy-App zu bauen. Er dokumentiert *alle* Verträge
zwischen App-Repo und Plattform — was die Plattform vom Repo erwartet
(HARD), was sie nutzt aber tolerant gegenüber Lücken ist (SOFT) und was wir
zur eigenen Lesbarkeit empfehlen (RECOMMENDED).

**Konventionen in diesem Dokument:**

- **HARD** — Verstoß lässt Deploy/Approval/Wizard hart scheitern.
- **SOFT** — Plattform funktioniert weiter, aber UI verliert Detail oder rendert Defaults.
- **RECOMMENDED** — Code-Review-Konvention, keine technische Wirkung.

Code-Referenzen verlinken auf `backend/`, `worker/` und Fixtures im Repo der
Plattform; alle Pfade sind relativ zum Plattform-Root.

---

## 1. Was ist eine App?

Eine App ist ein **Git-Repo** (GitHub oder GitLab) mit einem `terraform/`-
Verzeichnis und einem optionalen `packer/`-Verzeichnis. Die Plattform klont
das Repo bei jedem Deploy auf einen versionierten Git-Tag, baut die in
`packer/` definierten Glance-Images (sofern vorhanden) und wendet den
`terraform/`-Plan gegen das OpenStack-Backend an. Die durch Terraform
exportierten Outputs werden vom Backend gelesen, um Zugangsdaten an die
Endnutzer zu mailen und das Infrastruktur-Panel im UI zu rendern.

---

## 2. Minimum-Viable-App

Das kleinste funktionierende Repo-Layout besteht aus drei Dateien in einem
`terraform/`-Verzeichnis. **Kein `packer/`-Verzeichnis nötig** — die App
nutzt dann ein existierendes Glance-Image aus dem Cloud-Tenant.

```
my-app/
└── terraform/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

### `terraform/variables.tf`

```hcl
# Pflicht-Variable: der Worker injiziert hier das Team-Roster.
# Auch wenn die App keine Teams nutzt, MUSS sie deklariert sein.
variable "users" {
  description = "Per-team roster — vom Worker injiziert. @platform:internal"
  type        = map(list(object({
    email = string
  })))
  default     = {}
}

# Vom Wizard auswählbar:
variable "flavor_name" {
  description = "VM-Größe @openstack:flavor:name"
  type        = string
  default     = "gp1.small"
}

variable "network_uuid" {
  description = "Hauptnetzwerk @openstack:network:id"
  type        = string
}
```

### `terraform/main.tf`

```hcl
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

# HARD: clouds.yaml-Profilname MUSS "openstack" sein.
# Der Worker mountet die clouds.yaml entsprechend.
provider "openstack" {
  cloud = "openstack"
}

resource "openstack_compute_instance_v2" "vm" {
  name        = "my-app-vm"
  image_name  = "Ubuntu 22.04"
  flavor_name = var.flavor_name

  network {
    uuid = var.network_uuid
  }
}
```

### `terraform/outputs.tf`

```hcl
# HARD wenn die App Mails versenden will:
output "user_accounts" {
  sensitive = true
  value     = {}  # leer ist legal — Plattform versendet keine Credential-Mails
}

# SOFT — UI rendert leere Map als "keine Team-VMs"
output "team_vms" {
  value = {}
}

output "teams_summary" {
  value = {}
}
```

Das ist alles. Mit diesem Repo, einem Git-Tag `v0.1.0` und einer Approval
durch einen Plattform-Admin ist die App deploy-fähig.

### Was die Plattform automatisch beisteuert

Beim Deploy injiziert der Worker zusätzliche Variablen, die in
`variables.tf` deklariert sein **müssen** — sonst lehnt Terraform mit
`Value for undeclared variable` ab:

- `users` — siehe oben, immer injiziert sobald Teams im Draft existieren.
- `image_name` (Single-Image) bzw. `image_name_<key>` (Multi-Image) — nur
  wenn `packer/` existiert. Details siehe §7.

---

## 3. Variablen mit dem `@openstack`-Marker

Der `@openstack`-Marker im `description`-String einer Terraform- oder
Packer-Variable steuert, welches UI-Element der Wizard rendert. Ohne
Marker bekommt der User nur ein Free-Text-Feld.

**Grammatik** :

```
@openstack:<type>[:<mode>][:<multi>][:<var_scope>]
```

Das `@openstack`-Prefix matched **case-insensitive** — `@OpenStack:flavor`
und `@openstack:flavor` sind äquivalent. Empfohlen ist die lowercase-
Schreibweise als kanonische Form.

**Mehrere Marker pro Description** sind kein Fehler — der erste Marker
mit bekanntem Type gewinnt, unbekannte Types werden still übersprungen.


| Slot | Werte | Default |
|---|---|---|
| `type` | `network`, `subnet`, `flavor`, `image`, `keypair`, `security_group`, `floating_ip_pool`, `volume`, `router`, `availability_zone`, `file` | — |
| `mode` | `id`, `name` | `name` |
| `multi` | `single`, `multi` / `list` | aus HCL-Typ abgeleitet |
| `var_scope` | `all`, `team`, `user` | `all` |

### Häufige Marker-Formen

```hcl
# Ein Netzwerk-Picker (Name), Single-Select:
variable "network_name" {
  description = "@openstack:network:name Primäres Netzwerk"
  type        = string
}

# Network-Picker mit UUID-Modus, List-Select (für Packer):
variable "networks" {
  description = "@openstack:network:id:list Build-Netzwerke"
  type        = list(string)
}

# Flavor-Picker, einer pro Team:
variable "team_flavor_ids" {
  description = "@openstack:flavor:id:single:team Flavor pro Team"
  type        = map(string)
  default     = {}
}

# Security-Group-Picker, Multi-Select:
variable "secgroups" {
  description = "@openstack:security_group:name:multi"
  type        = list(string)
}
```

### Short-form var_scope-Marker

Bei reinen var_scope-Markern ist die volle Form `@openstack:::team` (drei
leere Slots, Scope im vierten). Der Parser toleriert aber auch die
Kurzform `@openstack::team` (Scope im Mode-Slot) als Shortcut. Beide Formen sind äquivalent.

### `var_scope` und der HCL-Typ (HARD)

Wenn `var_scope` `team` oder `user` ist, muss der HCL-Typ ein `map(...)`
sein — der Wizard schickt `{slot_key: value}` an Terraform. Andernfalls
schlägt die Approval mit `MARKER_SCOPED_REQUIRES_MAP` fehl. Details zu Team-/User-Scope siehe §5.

### Packer-Beschränkung (HARD)

In Packer-Variablen ist `var_scope=team` oder `=user` **verboten** — eine
Packer-Build erzeugt ein einziges Image, das von allen Teams/Usern
gemeinsam genutzt wird. Der Fehlercode ist `MARKER_PACKER_SCOPE_FORBIDDEN`.

---

## 4. `@platform:internal`-Variablen

Variablen, die vom Worker zur Laufzeit injiziert werden, sollen **nicht** im
Wizard erscheinen. Markiere sie mit `@platform:internal` im `description`-
Feld:

```hcl
variable "image_name" {
  description = "Glance-Image-Name — vom Worker zur Apply-Zeit gesetzt. @platform:internal"
  type        = string
}

variable "users" {
  description = "Per-team roster — vom Worker injiziert. @platform:internal"
  type        = map(list(object({ email = string })))
  default     = {}
}
```

**Was injiziert wird** (HARD-Deklaration, RECOMMENDED-Marker):

| Variable | Wert | 
|---|---|
| `image_name` (Single-Image) | `f"{app_id}-{image_tag}"` |
| `image_name_<key>` (Multi-Image) | `f"{app_id}-{key}-{image_tag}"` | 

Fehlende Deklaration → Terraform bricht mit "Value for undeclared variable"
ab. Fehlender `@platform:internal`-Marker → die Variable taucht im Wizard
auf und kann fälschlich überschrieben werden.

**Sonderfall** (HARD): Im Terraform-Parser werden `image_name` und `users`
zusätzlich namensbasiert ausgeblendet, auch ohne Marker.
Der Packer-Parser filtert nur `image_name`.

---

## 5. var_scope: pro Team / pro User

Wenn jeder Team oder User einen eigenen Wert für eine Variable wählen
können soll, hängt man `:team` oder `:user` ans Marker-Ende. Der Wizard
rendert dann einen Picker **pro Slot** und übergibt das Ergebnis als Map an
Terraform.

### Beispiel: Flavor pro Team

```hcl
variable "team_flavor_ids" {
  description = "@openstack:flavor:id:single:team Flavor pro Team"
  type        = map(string)   # HARD: muss map(...) sein
  default     = {}
}

locals {
  # Team-Keys werden aus dem injizierten ``users``-Roster abgeleitet.
  teams = keys(var.users)
}

resource "openstack_compute_instance_v2" "team_vm" {
  for_each = toset(local.teams)

  name = "vm-${each.key}"

  # OpenStack-Provider verlangt: genau einer von flavor_id/flavor_name
  # gesetzt, der andere null. Wenn das Team einen flavor_id-Pick hat
  # nehmen wir den, sonst fallback auf den Namen aus local.flavor.
  flavor_id   = try(var.team_flavor_ids[each.key], null)
  flavor_name = try(var.team_flavor_ids[each.key], null) == null ? local.flavor : null

  # ... weitere Felder ...
}
```

### Beispiel: Free-Text-Variable pro User

Wenn man kein OpenStack-Resource-Typ braucht, sondern nur eine
ungetypte User-Eingabe, lässt man den `type`-Slot leer:

```hcl
variable "github_handles" {
  description = "@openstack:::user GitHub-Username pro Endnutzer"
  type        = map(string)
  default     = {}
}
```

Der Wizard rendert hier ein Free-Text-Feld pro User.

### Multi-Werte pro Slot (hier Team)

`map(list(string))` mit `:multi:team` ist erlaubt — der Parser entpackt
den Wrapper und validiert nur den inneren Typ:

```hcl
variable "team_secgroups" {
  description = "@openstack:security_group:name:multi:team"
  type        = map(list(string))
  default     = {}
}
```

---

## 6. File-Upload-Variablen

Mit dem `@openstack:file:`-Marker rendert der Wizard eine
FileDropZone-Komponente. Datei-Inhalt landet base64-encodiert in einer
Terraform-Map und kann per `cloud-init` materialisiert werden.

### Marker-Form (HARD)

```
@openstack:file:<scope>:<ext1>|<ext2>|...
```

- `<scope>` ∈ `all` | `team` | `user`
- `<ext1>|<ext2>` — Pipe-separierte Liste erlaubter Extensions (lowercase,
  ohne Punkt). MUSS vorhanden sein; Kommas oder leere Liste → Approval-
  Error `MARKER_FILE_MISSING_EXTENSIONS`/`MARKER_FILE_INVALID_EXTENSIONS`.
- **Nur `|` als Trenner** (HARD): `@openstack:file:all:pdf,docx` schlägt
  mit `MARKER_FILE_INVALID_EXTENSIONS` fehl; nutze
  `@openstack:file:all:pdf|docx`.
- **Packer-Forbid** (HARD): File-Marker sind in Packer-Variablen verboten.

### HCL-Typ-Vertrag (HARD)

| Scope | HCL-Typ |
|---|---|
| `all` | `map(object({ name=string, content_b64=string, content_type=string, size=number }))` |
| `team` | `map(map(object({ … wie oben … })))` |
| `user` | `map(map(object({ … wie oben … })))` |

Siehe `apps.py:805-841` (`_validate_file_var_shape`). Der Worker injiziert
das Objekt mit den Attributen `{name, content_b64, size, content_type}`
(siehe `backend/app/routers/deployments.py:442-447`).

### Beispiel: ein Upload-Slot, geteilt

```hcl
variable "assignment_files" {
  description = <<-EOT
    @openstack:file:all:pdf
    Aufgabenstellung — eine PDF für alle Teams.
  EOT
  type = map(object({
    name         = string
    content_b64  = string
    content_type = string
    size         = number
  }))
  default = {}
}
```

Konsum in cloud-init — die Map kommt via
`templatefile("user-data.yaml.tpl", { assignment_files = var.assignment_files })`
in `main.tf` an:

```yaml
write_files:
%{ for slot_key, file in assignment_files ~}
  - path: /opt/app/${file.name}
    permissions: "0644"
    encoding: b64
    content: ${file.content_b64}
%{ endfor ~}
```

### Beispiel: ein Slot pro Team

```hcl
variable "team_briefings" {
  description = "@openstack:file:team:pdf|docx Briefing-Doku pro Team"
  type = map(map(object({
    name         = string
    content_b64  = string
    content_type = string
    size         = number
  })))
  default = {}
}
```

Der äußere Map-Key ist die Team-ID, der innere der Slot-Key.

### Worker-Verhalten bei Destroy (HARD)

Beim Destroy strippt der Worker alle file-shaped Variablen aus dem
`-var`-Set. Apps dürfen file-Variablen
deshalb **nicht** in `count = …` oder `for_each = …` referenzieren — beim
Destroy wäre der Wert dann leer und Terraform würde Resources fälschlich
löschen wollen, die der State noch kennt.

### Cloud-init-Größe (SOFT)

Terraform-Variablen >120 KiB lösen eine Warnung aus
— die Schwelle gilt **pro Variable** über
das gesamte var-Set, nicht nur für file-Variablen.

---

## 7. Multi-Image-Apps

Eine App kann mehrere Images parallel bauen. Der Wechsel ist ein reines
**Verzeichnis-Layout** — kein Schalter, kein Manifest.

### Packer-Layout (HARD)

```
my-app/
└── packer/
    ├── webserver/
    │   ├── template.pkr.hcl
    │   └── variables.pkr.hcl
    └── database/
        ├── template.pkr.hcl
        └── variables.pkr.hcl
```

- **Subdirectory-Key** (HARD): `[a-z][a-z0-9_-]{0,30}`. Ungültige Keys → `PackerTemplateDiscoveryError`.
- **Build-Reihenfolge** (RECOMMENDED-Awareness): alphabetisch nach Key. `database` baut vor `webserver`.
- **Subdirectories ohne `template.pkr.hcl`** (z.B. `_common/`, `scripts/`) werden
  still ignoriert.
- **Single + Multi gleichzeitig verboten** (HARD): wenn `packer/template.pkr.hcl`
  UND `packer/<key>/template.pkr.hcl` existieren, kippt die Discovery mit
  `PackerTemplateDiscoveryError`.

### Pro-Slice-Variablen in Packer

In jedem Slice referenziert das Template `var.image_name` — **nicht**
`var.image_name_<key>`. Der Worker injiziert pro Build den korrekten
Namen:

```hcl
# packer/webserver/variables.pkr.hcl
variable "image_name" {
  type        = string
  description = "Glance-Image-Name — vom Worker zur Build-Zeit gesetzt."
}
```

```hcl
# packer/webserver/template.pkr.hcl
source "openstack" "image" {
  image_name        = var.image_name
  source_image_name = "Ubuntu 22.04"
  flavor            = "gp1.small"
  # ...
}

build {
  sources = ["source.openstack.image"]
  # ... Provisioner ...
}
```

### Pro-Slice-Variablen in Terraform (HARD)

Für jeden Packer-Key eine separate `image_name_<key>`-Deklaration mit
`@platform:internal`:

```hcl
variable "image_name_webserver" {
  description = "Glance-Image-Name des Webserver-Slices — vom Worker gesetzt. @platform:internal"
  type        = string
}

variable "image_name_database" {
  description = "Glance-Image-Name des Database-Slices — vom Worker gesetzt. @platform:internal"
  type        = string
}
```

---

## 8. Output-Verträge

Drei Outputs werden vom Backend gelesen. Auch wenn die App leer ist:
**alle drei mit `{}` deklarieren**, sonst rendert das UI `None` und
Welcome-Mails brechen still.

### `user_accounts` (HARD wenn Mails gewünscht)

Pro Endnutzer-Account ein Eintrag. Backend rendert daraus die Access-Mail.

```hcl
output "user_accounts" {
  sensitive = true
  value = {
    "team-a-alice" = {
      username = "alice"
      type     = "password"
      auth     = "hunter2"
      ip       = "10.0.1.42"
      port     = 8080
    }
  }
}
```

**Auth-Typen**:

| `type` | Mail-Rendering | `auth`-Inhalt |
|---|---|---|
| `password` (Default bei Auslassung oder unbekanntem Wert) | "Password: …" | Passwort-String |
| `ssh_key` | Monospace SSH-Key-Block | Public-Key oder Hinweistext |
| `oauth` | "Login at …"-Link | Login-URL |
| `none` | Kein Credential-Block | `auth` darf fehlen |

**Account-Key-Vertrag** (HARD): Der Key MUSS die Form
`<normalised_team_name>-<username>` haben. Der Notifier matched Keys, indem
er das normalisierte Team-Prefix abschneidet, um den Username zu finden.

**Account-Key-Matcher** (SOFT): Backend normalisiert Keys (collapse
`./-/_`/Space → `-`, lowercase) und matched gegen `username`, Email-Local-
Part, `"firstName lastName"`. Wer abweichende Keys hat, riskiert
unzustellbare Mails.

### `metadata.team` auf Compute-Instanzen (SOFT)

```hcl
resource "openstack_compute_instance_v2" "team_vm" {
  for_each = toset(local.teams)
  name     = "vm-${each.key}"

  metadata = {
    team = each.key   # SOFT — ohne Tag landet die VM unter "Shared"
  }
  # ...
}
```

Backend liest den Tag und gruppiert die Karten im Infrastruktur-Panel danach.

**Sichtbare Resource-Typen** (informativ): nur sechs OpenStack-Typen
landen im Panel: `compute_instance_v2`,
`networking_network_v2`, `networking_subnet_v2`, `networking_secgroup_v2`,
`networking_floatingip_v2`, `networking_port_v2`. Volumes, Router etc.
werden ignoriert.

---

## 9. App-Version-Workflow

### Version = Git-Tag (HARD)

Die Plattform deployt **keinen Branch**, sondern ausschließlich
annotierte/lightweight Git-Tags, die im Repo existieren. Tag-Liste wird
via Provider-REST-API geholt (GitHub `/tags`, GitLab äquivalent).

### Tag-Format (RECOMMENDED)

Semver-style `vX.Y.Z` — der Sortierer parst die Numerik. Andere
Tag-Formate (`release-2026-06`, `prod`) funktionieren, sortieren aber nur
lexikographisch und führen im Wizard zur falschen "neueste Version"-
Auswahl.

---