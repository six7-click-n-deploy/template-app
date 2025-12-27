packer {
  required_plugins {
    openstack = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/openstack"
    }
  }
}

variable "image_name" {
  type        = string
  default     = "deploy-o-matic-image"
  description = "Name of the image to build"
}

variable "source_image" {
  type        = string
  default     = "Ubuntu 22.04"
  description = "Base image to build from"
}

variable "flavor" {
  type        = string
  default     = "gp1.small"
  description = "Instance size for build VM"
}

variable "networks" {
  type        = list(string)
  default     = ["4971e080-966d-485e-a161-3e2b7fefad53"]
  description = "Network IDs or names for build VM"
}

variable "floating_ip_pool" {
  type        = string
  default     = "DHBW"
  description = "External network for floating IP (not used if use_floating_ip=false)"
}

variable "security_group" {
  type        = string
  default     = "default"
  description = "Security group with SSH access for the build VM"
}

source "openstack" "deploy_o_matic" {
  image_name        = var.image_name
  source_image_name = var.source_image
  flavor            = var.flavor
  networks          = var.networks

  use_blockstorage_volume = true
  volume_size             = 10

  use_floating_ip = false

  ssh_ip_version  = "4"
  ssh_timeout     = "15m"
  ssh_username    = "ubuntu"

  security_groups = [var.security_group]
}

build {
  sources = ["source.openstack.deploy_o_matic"]

  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init...'",
      "cloud-init status --wait || true"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Updating package lists...'",
      "sudo apt-get update"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Installing nginx...'",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx",
      "sudo systemctl enable nginx"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Writing Deploy-O-Matic app page...'",
      "sudo tee /var/www/html/index.html > /dev/null <<'HTML'\n<!doctype html>\n<html lang=\"de\">\n<head>\n  <meta charset=\"utf-8\" />\n  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n  <title>Deploy-O-Matic</title>\n  <style>\n    body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,Cantarell,Noto Sans,sans-serif;max-width:900px;margin:40px auto;padding:0 16px;line-height:1.45}\n    .card{border:1px solid #ddd;border-radius:14px;padding:18px 18px 14px;box-shadow:0 6px 18px rgba(0,0,0,.06)}\n    h1{margin:0 0 6px;font-size:28px}\n    p{margin:10px 0}\n    .excuse{font-size:22px;margin:14px 0 10px}\n    button{border:0;border-radius:10px;padding:10px 14px;font-size:16px;cursor:pointer}\n    .meta{opacity:.72;font-size:13px;margin-top:14px}\n    code{background:#f6f6f6;padding:2px 6px;border-radius:8px}\n  </style>\n</head>\n<body>\n  <div class=\"card\">\n    <h1>🤖 Deploy-O-Matic</h1>\n    <p>Deine zufällige Deployment-Ausrede – frisch gebacken aus dem Image.</p>\n\n    <div class=\"excuse\" id=\"excuse\">…</div>\n    <button onclick=\"newExcuse()\">Neue Ausrede</button>\n\n    <p class=\"meta\">\n      Host: <code id=\"host\">unknown</code> · Zeit: <code id=\"time\">unknown</code>\n    </p>\n  </div>\n\n  <script>\n    const excuses = [\n      \"Das war kein Bug – das war ein Feature mit Überraschungseffekt.\",\n      \"Klappt bei mir lokal. (Lokal = Gedankenexperiment)\",\n      \"Das Monitoring ist nur nervös, weil es Gefühle hat.\",\n      \"Wir haben die Latenz heute auf ‚cinematisch‘ gestellt.\",\n      \"Ich hab’s nicht gelöscht, ich hab’s archiviert… dynamisch.\",\n      \"Der Fehler ist nur ein Easter Egg für aufmerksame Nutzer.\",\n      \"Das war ein heißer Fix – leider ohne Topflappen.\",\n      \"DNS. Immer DNS. (Auch wenn’s nicht DNS ist.)\"\n    ];\n\n    function newExcuse(){\n      const pick = excuses[Math.floor(Math.random()*excuses.length)];\n      document.getElementById('excuse').textContent = pick;\n      document.getElementById('time').textContent = new Date().toISOString();\n    }\n\n    // Best effort hostname (falls server es setzt)\n    document.getElementById('host').textContent = window.location.hostname;\n    newExcuse();\n  </script>\n</body>\n</html>\nHTML"
    ]
  }

  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*"
    ]
  }
}
