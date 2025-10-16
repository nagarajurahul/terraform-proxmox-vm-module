output "vm_ipv4_addresses" {
  value       = proxmox_virtual_environment_vm.vm.ipv4_addresses
  description = "IP addresses assigned to the Proxmox Virtual Machine"
}

output "vm_hostname" {
  value       = var.vm_hostname
  description = "Hostname of the Proxmox Virtual Machine"
}