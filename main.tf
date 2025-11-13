terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
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
  userdata_rendered = templatefile(
    var.control_server ? "${path.module}/control-server-userdata.tpl" : "${path.module}/userdata.tpl",
    {
      HOSTNAME     = var.vm_hostname
      DNS_DOMAIN   = var.dns_domain
      CA_ROOT_CRT  = var.ca_root_certificate
      git_username = var.git_username
      git_email    = var.git_email
      users        = var.users # No need to jsonencode here!
    }
  )

  network_rendered = templatefile(
    "${path.module}/network.tpl",
    {
      DRIVER      = var.network_driver
      DNS_SERVERS = join(", ", [for s in var.dns_servers : format("%q", s)])
      DNS_DOMAIN  = var.dns_domain
    }
  )
}

resource "proxmox_virtual_environment_file" "cloud_config" {
  # Please make sure these folders exist
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    data      = local.userdata_rendered
    file_name = "${var.vm_hostname}.cloud-config.yaml"
  }
}

resource "proxmox_virtual_environment_file" "network_config" {
  # Please make sure these folders exist
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    data      = local.network_rendered
    file_name = "${var.vm_hostname}.network.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  description = var.description
  tags        = var.tags

  node_name  = var.node_name
  on_boot    = var.vm_on_boot

  # Please set accordingly, disables remove operations on VM and disks
  protection = var.vm_protection

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
    type    = var.network_model
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
    datastore_id          = var.datastore_id
    user_data_file_id     = proxmox_virtual_environment_file.cloud_config.id
    network_data_file_id  = proxmox_virtual_environment_file.network_config.id
    
    # Not needed as passed via network-config
    # dns {
    #   domain  = var.dns_domain
    #   servers = var.dns_servers
    # }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  disk {
    datastore_id = var.datastore_id
    # qcow2 image downloaded from https://cloud.debian.org/images/cloud/bookworm/latest/ and renamed to *.img
    # the image is not of import type, so provider will use SSH client to import it
    import_from = var.iso_path
    # import_from = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface = "scsi0" # fastest for modern workloads
    iothread  = true    # Makes Docker, K8s faster
    discard   = "on"    # industry standard to follow during thin-provision and ssds
    backup    = true
    replicate = true
    size      = var.disk_size
  }

  network_device {
    bridge = var.network_bridge
    model  = var.network_model
  }

  efi_disk {
    datastore_id = var.datastore_id
    type         = "4m"
  }
}

# resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
#   content_type = "import"
#   datastore_id = "local"
#   node_name    = var.node_name
#   url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
#   # need to rename the file to *.qcow2 to indicate the actual file format for import
#   file_name = "noble-server-cloudimg-amd64.qcow2"
# }