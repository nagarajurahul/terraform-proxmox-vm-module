##############################################
# Proxmox Provider Variables
##############################################

variable "virtual_environment_endpoint" {
  type        = string
  description = <<EOT
The API endpoint of your Proxmox Virtual Environment.
Example: "https://192.168.0.120:8006/api2/json"
Used by the provider to communicate with the Proxmox API.
EOT

  validation {
    condition     = can(regex("^https://", var.virtual_environment_endpoint))
    error_message = "Endpoint must start with https://"
  }
}

variable "virtual_environment_api_token" {
  type        = string
  sensitive   = true
  description = <<EOT
The API token used to authenticate with the Proxmox VE API.
Recommended format: "user@pam!tokenid=tokenvalue".
Store securely in environment variables or Terraform Cloud variables.
EOT

  validation {
    condition     = can(regex("^[^@]+@[^!]+![^=]+=.+$", var.virtual_environment_api_token))
    error_message = "API token must be in format: user@realm!tokenid=secret"
  }
}

variable "virtual_environment_username" {
  type        = string
  description = <<EOT
The SSH username used for Proxmox host.
For example: "root".
EOT
}

##############################################
# VM Identity and Metadata
##############################################

variable "vm_name" {
  type        = string
  description = "Name of the virtual machine as shown in the Proxmox UI."
}

variable "vm_hostname" {
  type        = string
  description = "Hostname for the VM, passed to the cloud-init template."
}

variable "description" {
  type        = string
  default     = "Terraform-provisioned VM"
  description = "Optional description for the VM."
}

variable "tags" {
  type        = list(string)
  default     = ["terraform", "cloud-init"]
  description = "List of tags to assign to the VM for UI filtering and grouping."
}

variable "vm_on_boot" {
  type        = bool
  default     = true
  description = "Whether the VM should automatically start when the node boots."
}

variable "vm_protection" {
  type        = bool
  default     = true
  description = "Whether the VM and disks should be protected from deletions."
}

##############################################
# Proxmox Node and Storage Configuration
##############################################

variable "node_name" {
  type        = string
  default     = "pve"
  description = "Name of the Proxmox node where the VM should be created."
}

variable "datastore_id" {
  type        = string
  default     = "local-lvm"
  description = <<EOT
The Proxmox datastore ID where disks, EFI, and TPM state are stored.
Examples: "local-lvm", "ceph-storage", "ssd-pool".
EOT
}

variable "iso_path" {
  type        = string
  description = <<EOT
Path or URL to the base cloud image (qcow2 or img) to import into Proxmox.
For example:
"/root/images/debian-12-genericcloud-amd64.img"
or a valid remote URL.
EOT
}

##############################################
# Operating System Settings
##############################################

variable "operating_system" {
  type        = string
  default     = "l26"
  description = <<EOT
Operating system type recognized by Proxmox for VM optimization.
Common values: "l26" for Linux, "win11" for Windows 11, "other".
EOT
}

##############################################
# CPU and Memory Configuration
##############################################

variable "cpu" {
  type        = number
  default     = 2
  description = <<EOT
Number of vCPU cores assigned to the VM.
For high-IO or compute workloads, 4–8 is typical.
EOT
}

variable "memory" {
  type        = number
  default     = 2048
  description = <<EOT
Amount of dedicated memory (in MB) for the VM.
The same value is used for 'floating' memory to enable ballooning.
EOT
}

variable "disk_size" {
  type        = number
  default     = 8
  description = <<EOT
Disk Size (in GB) for the VM.
Please choose this based on your requirements for specific use case.
EOT
}

##############################################
# Network Configuration
##############################################

variable "network_bridge" {
  type        = string
  default     = "vmbr0"
  description = "Proxmox bridge to attach VM network interfaces (e.g., vmbr0)."
}

variable "network_model" {
  type        = string
  default     = "virtio"
  description = "Virtual network interface model for the VM (e.g., virtio, e1000, rtl8139)."
}

variable "network_driver" {
  type        = string
  default     = "virtio_net"
  description = "The network interface driver used inside the VM (for cloud-init matching). Common values include virtio_net for VirtIO, e1000 for Intel E1000, or vmxnet3 for VMware-compatible NICs."
}

##############################################
# DNS Configuration
##############################################

variable "dns_servers" {
  type        = list(string)
  description = "List of DNS servers to configure in the VM"
}

variable "dns_domain" {
  type        = string
  default     = "homelab.local"
  description = "DNS Domain"
}

##############################################
# Certificates Configuration
##############################################

variable "ca_root_certificate" {
  type        = string
  default     = ""
  description = "Root Certificate of the Certificate Authority"
}

##############################################
# Cloud-Init / User Data Variables
##############################################

variable "users" {
  type = map(object({
    hashed_password     = string
    ssh_authorized_keys = list(string)
  }))
  description = <<EOT
Map of user definitions for the cloud-init template.

Example:
"users": {
    "ubuntu": {
        "hashed_password": "hashed-secret-password",
        "ssh_keys": [
            "ssh-ed25519 ssh-key-1",
            "ssh-ed25519 ssh-key-2"
        ]
    },
    "rahul": {
        "hashed_password": "hashed-secret-password",
        "ssh_keys": [
            "ssh-ed25519 ssh-key-1",
            "ssh-ed25519 ssh-key-2"
        ]
    }
}
EOT
}

##############################################
# Control Server Flag
##############################################

variable "control_server" {
  type        = bool
  description = "Please define whether this is control server or not"
  default     = false
}

##############################################
# Git Config
##############################################

variable "git_username" {
  type        = string
  description = "Git Username"
  default     = "git_username"
}

variable "git_email" {
  type        = string
  description = "Git Email"
  default     = "git_email@email.com"
}

##############################################
# Optional Security and Lifecycle Settings
##############################################

variable "tpm_version" {
  type        = string
  default     = "v2.0"
  description = "TPM module version (v2.0 required for Windows 11 / Secure Boot)."
}

##############################################
# Example Usage Notes
##############################################
# - virtual_environment_endpoint : Proxmox API URL
# - virtual_environment_api_token: Must be generated in Proxmox UI
# - node_name                    : Use 'pve' or your actual node hostname
# - datastore_id                 : Use 'local-lvm' if you’re using default Proxmox storage
# - iso_path                     : Path to your cloud-init image (.img or .qcow2)
# - users                        : List of accounts injected via cloud-init
##############################################

