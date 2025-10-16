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
}

variable "virtual_environment_api_token" {
  type        = string
  sensitive   = true
  description = <<EOT
The API token used to authenticate with the Proxmox VE API.
Recommended format: "user@pam!tokenid=tokenvalue".
Store securely in environment variables or Terraform Cloud variables.
EOT
}

variable "virtual_environment_username" {
  type        = string
  description = <<EOT
The SSH username used when importing disk images via SSH.
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

##############################################
# Proxmox Node and Storage Configuration
##############################################

variable "node_name" {
  type        = string
  description = "Name of the Proxmox node where the VM should be created."
}

variable "datastore_id" {
  type        = string
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
# Cloud-Init / User Data Variables
##############################################

variable "default_user" {
  type        = string
  default     = "ubuntu"
  description = "Default user to be configured in the cloud-init template."
}

variable "users" {
  type = map(object({
    password            = string
    ssh_authorized_keys = list(string)
  }))
  description = <<EOT
Map of user definitions for the cloud-init template.

Example:
"users": {
    "ubuntu": {
        "password": "secret-password",
        "ssh_keys": [
            "ssh-ed25519 ssh-key-1",
            "ssh-ed25519 ssh-key-2"
        ]
    },
    "rahul": {
        "password": "secret-password",
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

