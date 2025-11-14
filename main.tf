terraform {
  required_version = "~> 1.13.0"

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


##############################################
# Local Variables & Template Rendering
##############################################

locals {
  # Select appropriate cloud-init template based on server type
  userdata_template = var.control_server ? "control-server-userdata.tpl" : "userdata.tpl"

  userdata_rendered = templatefile(
    "${path.module}/${local.userdata_template}",
    {
      HOSTNAME     = var.vm_hostname
      DNS_DOMAIN   = var.dns_domain
      CA_ROOT_CRT  = trimspace(var.ca_root_certificate)
      environment  = var.environment
      git_username = var.git_username
      git_email    = var.git_email
      users        = var.users
      LOCK_PASSWORD = var.lock_password
    }
  )

  network_rendered = templatefile(
    "${path.module}/network.tpl",
    {
      DRIVER      = var.network_driver
      DNS_SERVERS = jsonencode(var.dns_servers)
      DNS_DOMAIN  = var.dns_domain
    }
  )
}


##############################################
# Cloud-Init Configuration Files
##############################################

resource "proxmox_virtual_environment_file" "cloud_config" {
  # Please make sure these folders exist
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    data      = local.userdata_rendered
    file_name = "${var.vm_hostname}.cloud-config.yaml"
  }

  lifecycle {
    create_before_destroy = true
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

  lifecycle {
    create_before_destroy = true
  }
}


##############################################
# Virtual Machine Resource
##############################################

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  description = var.description
  tags        = var.tags

  node_name = var.node_name
  on_boot   = var.vm_on_boot
  started   = true

  # Please set accordingly for safety critical resources ex: like dns, cert or vault vms, disables remove operations on VM and disks when set to true
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
    version      = var.tpm_version
  }

  cpu {
    cores = var.cpu
    type  = "x86-64-v2-AES" # recommended for modern CPUs
    flags = ["+aes"]
  }

  memory {
    dedicated = var.memory
    floating  = var.memory # set equal to dedicated to enable ballooning
  }

  initialization {
    datastore_id         = var.datastore_id
    user_data_file_id    = proxmox_virtual_environment_file.cloud_config.id
    network_data_file_id = proxmox_virtual_environment_file.network_config.id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  # Boot disk
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
    ssd       = true # Enable SSD emulation for better performance
  }

  network_device {
    bridge = var.network_bridge
    model  = var.network_model
  }

  efi_disk {
    datastore_id = var.datastore_id
    type         = "4m"
  }

  lifecycle {
    prevent_destroy = false
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