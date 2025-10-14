provider "proxmox" {
  endpoint  = var.virtual_environment_endpoint
  api_token = var.virtual_environment_api_token
  insecure  = true
  ssh{
    agent    = true
    username = var.virtual_environment_username
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  description = var.description
  tags        = var.tags
  
  node_name = "pve"
  on_boot   = var.vm_on_boot
  protection = false

  machine = "q35" # Modern virtual motherboard model, has more support
  bios = "ovmf" # Modern, supports NVMe, faster, secure boot, GPU passthrough

  operating_system {
    type = var.operating_system
  }

  scsi_hardware = "virtio-scsi-pci"
  
  # QEMU, helpful to get IP and other things
  agent {
    enabled = true
    timeout = "10m"
    trim    = true
    type    = "virtio"
  }

  # Security is most imp
  tpm_state {
    datastore_id = "local-lvm"
    version = "v2.0"
  }
  
  cpu {
    cores        = var.cpu
    type         = "x86-64-v2-AES"  # recommended for modern CPUs
  }

  memory {
    dedicated = var.memory
    floating  = var.memory # set equal to dedicated to enable ballooning
  }

  disk {
    datastore_id = "local-lvm"
    # qcow2 image downloaded from https://cloud.debian.org/images/cloud/bookworm/latest/ and renamed to *.img
    # the image is not of import type, so provider will use SSH client to import it
    import_from   = var.iso_path
    interface = "virtio0" # fastest for modern workloads
    iothread  = true # Makes Docker, K8s faster
    discard   = "on" # industry standard to follow during thin-provision and ssds
    backup = true
    replicate = true
   }
}