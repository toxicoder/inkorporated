# VM Module Outputs
# Output values from the VM provisioning module

output "control_plane_ips" {
  description = "IP addresses of control plane VMs"
  value       = proxmox_vm_qemu.control_plane[*].ipconfig0
}

output "worker_node_ips" {
  description = "IP addresses of worker node VMs"
  value       = proxmox_vm_qemu.worker_node[*].ipconfig0
}

output "all_vm_ips" {
  description = "All VM IP addresses"
  value       = concat(
    proxmox_vm_qemu.control_plane[*].ipconfig0,
    proxmox_vm_qemu.worker_node[*].ipconfig0
  )
}

output "control_plane_names" {
  description = "Names of control plane VMs"
  value       = proxmox_vm_qemu.control_plane[*].name
}

output "worker_node_names" {
  description = "Names of worker node VMs"
  value       = proxmox_vm_qemu.worker_node[*].name
}

output "vm_names" {
  description = "All VM names"
  value       = concat(
    proxmox_vm_qemu.control_plane[*].name,
    proxmox_vm_qemu.worker_node[*].name
  )
}
