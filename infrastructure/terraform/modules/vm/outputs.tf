# VM Module Outputs
# Output values from the VM provisioning module

output "vm_id" {
  description = "VMID of the created VM"
  value       = proxmox_vm_qemu.this.vmid
}

output "vm_name" {
  description = "Name of the created VM"
  value       = proxmox_vm_qemu.this.name
}

output "vm_ip" {
  description = "IP address of the created VM"
  value       = proxmox_vm_qemu.this.ipconfig0
}