terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.85.1"
    }
  }
}

# provider "proxmox" {
#   endpoint  = var.virtual_environment_endpoint
#   api_token = var.virtual_environment_api_token
#   insecure  = true
#   ssh {
#     agent    = true
#     username = var.virtual_environment_username
#   }
# }

locals {
  userdata_rendered = templatefile("${path.module}/userdata.tpl", {
    HOSTNAME     = var.vm_hostname
    default_user = var.default_user
    users        = var.users # No need to jsonencode here!
  })
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    data      = local.userdata_rendered
    file_name = "${var.vm_hostname}.cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  description = var.description
  tags        = var.tags

  node_name  = var.node_name
  on_boot    = var.vm_on_boot
  protection = false

  machine = "q35"  # Modern virtual motherboard model, has more support
  bios    = "ovmf" # Modern, supports NVMe, faster, secure boot, GPU passthrough

  operating_system {
    type = var.operating_system
  }

  scsi_hardware = "virtio-scsi-single" # Faster for high-IO workloads like Docker, K8s

  # QEMU, helpful to get IP and other things
  agent {
    enabled = true
    timeout = "10m"
    trim    = true
    type    = "virtio"
  }

  # Security is most imp
  tpm_state {
    datastore_id = var.datastore_id
    version      = "v2.0"
  }

  cpu {
    cores = var.cpu
    type  = "x86-64-v2-AES" # recommended for modern CPUs
  }

  memory {
    dedicated = var.memory
    floating  = var.memory # set equal to dedicated to enable ballooning
  }

  initialization {
    datastore_id      = var.datastore_id
    user_data_file_id = proxmox_virtual_environment_file.cloud_config.id
  }

  disk {
    datastore_id = var.datastore_id
    # qcow2 image downloaded from https://cloud.debian.org/images/cloud/bookworm/latest/ and renamed to *.img
    # the image is not of import type, so provider will use SSH client to import it
    import_from = var.iso_path
    interface   = "scsi0" # fastest for modern workloads
    iothread    = true    # Makes Docker, K8s faster
    discard     = "on"    # industry standard to follow during thin-provision and ssds
    backup      = true
    replicate   = true
  }
}