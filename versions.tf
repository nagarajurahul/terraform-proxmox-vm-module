terraform {
  required_version = ">= 1.14.0, <1.20.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.85.1"
    }
  }
}