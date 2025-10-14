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
  
  cpu {
    cores        = 2
    type         = "x86-64-v2-AES"  # recommended for modern CPUs
  }

  memory {
    dedicated = 2048
    floating  = 2048 # set equal to dedicated to enable ballooning
  }

  disk {
    datastore_id = "local-lvm"
    # qcow2 image downloaded from https://cloud.debian.org/images/cloud/bookworm/latest/ and renamed to *.img
    # the image is not of import type, so provider will use SSH client to import it
    file_id   = var.iso_path
    interface = "virtio0"
    iothread  = true
    discard   = "on"
    size      = var.vm_disk_size
  }
}